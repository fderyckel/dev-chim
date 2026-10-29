"use client";

import { useRef, useState } from "react";
import Link from "next/link";
import { ActionButton } from "../design-system/components/actions";
import { demoHref } from "../lib/demo-institutions";
import {
  defaultHomeLayout,
  nextLayoutId,
  temporaryLayoutNotice,
  type DemoHomeLayout,
} from "../lib/demo-layout";
import type { DemoDestination } from "../lib/demo-navigation";
import { useDemoLayoutSession } from "./demo-layout-session";
import { DemoResetLayout } from "./demo-reset-layout";
import { DemoSectionEditor } from "./demo-section-editor";

export function DemoPersonalHome({
  packId,
  destinations,
}: {
  packId: string;
  destinations: readonly DemoDestination[];
}) {
  const session = useDemoLayoutSession(packId);
  const [selectedId, setSelectedId] = useState(session?.defaultHomeId ?? "home-1");
  const [draft, setDraft] = useState<DemoHomeLayout | null>(null);
  const [message, setMessage] = useState("");
  const region = useRef<HTMLElement>(null);
  const layoutSelector = useRef<HTMLSelectElement>(null);
  if (!session) return null;
  const layout =
    session.homeLayouts.find((candidate) => candidate.id === selectedId) ??
    session.homeLayouts[0];
  const finish = () =>
    requestAnimationFrame(() =>
      region.current?.querySelector<HTMLButtonElement>("button")?.focus(),
    );
  return (
    <section
      className="c-demo-personal-home"
      aria-label="Personal Home preview"
      ref={region}
    >
      {draft ? (
        <DemoSectionEditor
          key={draft.id}
          kind="home"
          initialName={draft.name}
          reservedNames={session.homeLayouts
            .filter((candidate) => candidate.id !== draft.id)
            .map((candidate) => candidate.name)}
          initialSections={draft.sections}
          destinations={destinations}
          onCancel={() => {
            setDraft(null);
            setMessage("Draft discarded. Your applied Home layout is unchanged.");
            finish();
          }}
          onApply={(sections, name) => {
            session.applyHome({ ...draft, name, sections });
            setSelectedId(draft.id);
            setDraft(null);
            setMessage(`${name} applied for this preview.`);
            finish();
          }}
        />
      ) : (
        <>
          <div className="c-demo-layout-heading">
            <h2>{layout.name}</h2>
            <p className="c-demo-muted">
              Personal Home preview · {temporaryLayoutNotice}
            </p>
          </div>
          <div className="c-demo-layout-toolbar">
            <label className="c-field">
              Home layout
              <select
                ref={layoutSelector}
                value={layout.id}
                onChange={(event) => {
                  setSelectedId(event.target.value);
                  setMessage(
                    "Layout selected. Institution and page access are unchanged.",
                  );
                }}
              >
                {session.homeLayouts.map((candidate) => (
                  <option key={candidate.id} value={candidate.id}>
                    {candidate.name}
                    {candidate.id === session.defaultHomeId ? " · Starting layout" : ""}
                  </option>
                ))}
              </select>
            </label>
            <ActionButton variant="secondary" onClick={() => setDraft(layout)}>
              Customize my Home
            </ActionButton>
            <ActionButton
              variant="quiet"
              disabled={session.homeLayouts.length >= 4}
              onClick={() => {
                const id = nextLayoutId(
                  "home",
                  session.homeLayouts.map((candidate) => candidate.id),
                );
                setDraft({
                  ...defaultHomeLayout(id),
                  name: `My Home ${id.split("-")[1]}`,
                });
              }}
            >
              New Home layout
            </ActionButton>
            {layout.id !== session.defaultHomeId ? (
              <ActionButton
                variant="quiet"
                onClick={() => {
                  session.makeDefault(layout.id);
                  requestAnimationFrame(() => layoutSelector.current?.focus());
                  setMessage(
                    `${layout.name} is your starting layout for this preview.`,
                  );
                }}
              >
                Make default
              </ActionButton>
            ) : (
              <span className="c-demo-muted">Starting layout</span>
            )}
            <DemoResetLayout
              label="Reset Home layout"
              description={`Replace only ${layout.name} with the built-in Home layout for this preview.`}
              onReset={() => {
                session.applyHome({
                  ...defaultHomeLayout(layout.id),
                  name: layout.name,
                });
                setMessage(
                  "This Home layout was reset. App organization and other layouts are unchanged.",
                );
              }}
            />
          </div>
          {session.homeLayouts.length >= 4 ? (
            <p className="c-demo-muted">
              This preview supports up to four Home layouts.
            </p>
          ) : null}
          {layout.sections.length === 0 ? (
            <p>
              No Home sections. Choose Customize my Home to add one, or reset this
              layout. Apps remains available.
            </p>
          ) : null}
          {layout.sections.map((section) => (
            <section
              className="c-demo-home-section"
              key={section.id}
              aria-label={section.label}
            >
              <h3>{section.label}</h3>
              <ul className="c-demo-home-links">
                {section.items.map((pageId) => {
                  const destination = destinations.find(
                    (candidate) => candidate.id === pageId,
                  )!;
                  return (
                    <li key={pageId}>
                      <Link href={demoHref(destination.href, packId)}>
                        {destination.label}
                      </Link>
                    </li>
                  );
                })}
              </ul>
              {section.items.length === 0 ? (
                <p className="c-demo-muted">No shortcuts in this section.</p>
              ) : null}
            </section>
          ))}
        </>
      )}
      <p className="c-demo-layout-announcement" role="status">
        {message}
      </p>
    </section>
  );
}
