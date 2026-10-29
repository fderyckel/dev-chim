import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useState } from "react";
import {
  DemoLayoutProvider,
  useDemoLayoutSession,
} from "../../src/components/demo-layout-session";
import { defaultHomeLayout } from "../../src/lib/demo-layout";

const route = vi.hoisted(() => ({ query: "" }));
vi.mock("next/navigation", () => ({
  useSearchParams: () => new URLSearchParams(route.query),
}));
afterEach(() => {
  cleanup();
  route.query = "";
});

function Surface({ packId }: { packId: string }) {
  const [draft, setDraft] = useState(false);
  const session = useDemoLayoutSession(packId);
  if (!session) return <p>Scope unavailable</p>;
  return (
    <>
      <button onClick={() => setDraft(true)}>Start draft</button>
      {draft ? <p>Unapplied draft marker</p> : null}
      <p>{session.appSections[0].label}</p>
      <p>{session.homeLayouts[0].name}</p>
      <button
        onClick={() =>
          session.applyApps([
            { id: "planning", label: "Planning", items: ["calendar"] },
          ])
        }
      >
        Apply groups
      </button>
      <button
        onClick={() => session.applyHome({ ...defaultHomeLayout(), name: "Morning" })}
      >
        Apply Home
      </button>
      <button
        onClick={() =>
          session.applyApps([
            { id: "bad", label: "Private", items: ["safeguarding" as "students"] },
          ])
        }
      >
        Invalid groups
      </button>
    </>
  );
}
const first = "bangkok-international";

describe("memory-only layout session", () => {
  it("keeps groups and Home independent across remounted pages, then clears both on institution change", () => {
    const view = (packId: string, page: string) => (
      <DemoLayoutProvider defaultPackId={first}>
        <Surface key={page} packId={packId} />
      </DemoLayoutProvider>
    );
    const { rerender } = render(view(first, "apps"));
    fireEvent.click(screen.getByText("Apply groups"));
    expect(screen.getByText("My Home")).toBeVisible();
    fireEvent.click(screen.getByText("Apply Home"));
    rerender(view(first, "home"));
    expect(screen.getByText("Planning")).toBeVisible();
    expect(screen.getByText("Morning")).toBeVisible();
    fireEvent.click(screen.getByText("Invalid groups"));
    expect(screen.queryByText("Private")).toBeNull();
    route.query = "demo=us-community-college";
    rerender(view("us-community-college", "home"));
    expect(screen.getByText("Students & support")).toBeVisible();
    expect(screen.getByText("My Home")).toBeVisible();
    expect(screen.queryByText("Planning")).toBeNull();
    route.query = "demo=unknown";
    rerender(view(first, "apps"));
    expect(screen.getByText("Scope unavailable")).toBeVisible();
  });

  it("discards temporary state after a full-page history restoration", () => {
    render(
      <DemoLayoutProvider defaultPackId={first}>
        <Surface packId={first} />
      </DemoLayoutProvider>,
    );
    fireEvent.click(screen.getByText("Apply Home"));
    fireEvent.click(screen.getByText("Start draft"));
    const restore = new Event("pageshow");
    Object.defineProperty(restore, "persisted", { value: true });
    act(() => window.dispatchEvent(restore));
    expect(screen.getByText("My Home")).toBeVisible();
    expect(screen.queryByText("Unapplied draft marker")).toBeNull();
  });
});
