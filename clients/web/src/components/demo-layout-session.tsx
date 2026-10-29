"use client";

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { useSearchParams } from "next/navigation";
import { isDemoInstitution } from "../lib/demo-institutions";
import {
  copySections,
  defaultAppSections,
  defaultHomeLayout,
  validLayoutLabel,
  validLayoutSections,
  type DemoHomeLayout,
  type DemoLayoutSection,
} from "../lib/demo-layout";

function initialState() {
  return {
    appSections: defaultAppSections(),
    homeLayouts: [defaultHomeLayout()],
    defaultHomeId: "home-1",
  };
}
type LayoutState = ReturnType<typeof initialState>;
type LayoutSession = LayoutState & {
  packId: string;
  applyApps: (sections: DemoLayoutSection[]) => void;
  applyHome: (layout: DemoHomeLayout) => void;
  makeDefault: (id: string) => void;
};
const DemoLayoutContext = createContext<LayoutSession | null>(null);

function DemoLayoutState({
  packId,
  children,
}: {
  packId: string;
  children: ReactNode;
}) {
  const [state, setState] = useState(initialState);
  const [restoration, setRestoration] = useState(0);
  useEffect(() => {
    function restore(event: PageTransitionEvent) {
      if (event.persisted) {
        setState(initialState());
        setRestoration((current) => current + 1);
      }
    }
    window.addEventListener("pageshow", restore);
    return () => window.removeEventListener("pageshow", restore);
  }, []);
  const value: LayoutSession = {
    ...state,
    packId,
    applyApps(sections) {
      if (validLayoutSections(sections))
        setState((current) => ({ ...current, appSections: copySections(sections) }));
    },
    applyHome(layout) {
      if (
        !/^home-[1-9][0-9]*$/.test(layout.id) ||
        !validLayoutLabel(layout.name) ||
        !validLayoutSections(layout.sections)
      )
        return;
      setState((current) => {
        const exists = current.homeLayouts.some(
          (candidate) => candidate.id === layout.id,
        );
        if (!exists && current.homeLayouts.length >= 4) return current;
        if (
          current.homeLayouts.some(
            (candidate) =>
              candidate.id !== layout.id &&
              candidate.name.toLocaleLowerCase() ===
                layout.name.trim().toLocaleLowerCase(),
          )
        )
          return current;
        const safe = {
          id: layout.id,
          name: layout.name.trim(),
          sections: copySections(layout.sections),
        };
        return {
          ...current,
          homeLayouts: exists
            ? current.homeLayouts.map((candidate) =>
                candidate.id === layout.id ? safe : candidate,
              )
            : [...current.homeLayouts, safe],
        };
      });
    },
    makeDefault(id) {
      setState((current) =>
        current.homeLayouts.some((layout) => layout.id === id)
          ? { ...current, defaultHomeId: id }
          : current,
      );
    },
  };
  return (
    <DemoLayoutContext.Provider key={restoration} value={value}>
      {children}
    </DemoLayoutContext.Provider>
  );
}

export function DemoLayoutProvider({
  defaultPackId,
  children,
}: {
  defaultPackId: string;
  children: ReactNode;
}) {
  const search = useSearchParams();
  const selected = search.getAll("demo");
  // This key discards presentation state. Validated data still comes only from DemoPage.
  const scope =
    selected.length === 0
      ? defaultPackId
      : selected.length === 1 && isDemoInstitution(selected[0])
        ? selected[0]
        : "unavailable";
  return (
    <DemoLayoutState key={scope} packId={scope}>
      {children}
    </DemoLayoutState>
  );
}

export function useDemoLayoutSession(packId: string) {
  const session = useContext(DemoLayoutContext);
  return session?.packId === packId ? session : null;
}
