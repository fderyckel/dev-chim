import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { run as runAccessibilityScan } from "axe-core";
import { describe, expect, it } from "vitest";

import { AppShell } from "../../src/components/app-shell";
import { HomeView } from "../../src/components/home-view";
import { InterfaceStateExplorer } from "../../src/components/interface-state-explorer";
import type {
  HomeViewData,
  InterfaceState,
  PrototypeContext,
} from "../../src/ports/view-data";

const context: PrototypeContext = {
  tenantName: "Synthetic Learning Community",
  tenantKind: "synthetic",
  dateLabel: "Example day",
  connectionLabel: "Local fixture · no server connection",
};

const home: HomeViewData = {
  context,
  priority: {
    eyebrow: "Suggested next step",
    title: "Review synthetic attention items",
    description: "No school record can be changed.",
    actionLabel: "Review attention items",
    actionHref: "#attention",
  },
  attention: [
    {
      id: "synthetic-attention",
      title: "Example needs context",
      detail: "Synthetic entry ready for review.",
      status: "1 example",
      tone: "attention",
    },
  ],
  activity: [
    {
      id: "synthetic-activity",
      label: "Prototype opened",
      detail: "Local browser session",
      time: "08:32",
    },
  ],
};

const states: ReadonlyArray<InterfaceState> = [
  {
    key: "ready",
    label: "Ready",
    title: "This view is up to date",
    description: "The synthetic information is ready.",
    recovery: "No action is needed.",
    tone: "positive",
  },
  {
    key: "denied",
    label: "Access unavailable",
    title: "You do not have access to this view",
    description: "Restricted details are not disclosed.",
    recovery: "Return to a view already available to you.",
    tone: "critical",
  },
];

describe("the UI-0 experience components", () => {
  it("presents a labelled, synthetic home experience through semantic landmarks", async () => {
    render(
      <AppShell activePage="home" context={context}>
        <HomeView viewData={home} />
      </AppShell>,
    );

    expect(screen.getByRole("link", { name: "Skip to main content" })).toHaveAttribute(
      "href",
      "#main-content",
    );
    expect(
      screen.getByRole("navigation", { name: "Primary navigation" }),
    ).toBeVisible();
    expect(screen.getByRole("link", { name: "Home" })).toHaveAttribute(
      "aria-current",
      "page",
    );
    expect(screen.getByRole("main")).toBeVisible();
    expect(
      screen.getByRole("heading", { level: 1, name: "A clear place to begin" }),
    ).toBeVisible();
    expect(screen.getByText("Synthetic tenant")).toBeVisible();
    expect(screen.getByText("Local prototype · synthetic data")).toBeVisible();

    const accessibility = await runAccessibilityScan(document.body, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(accessibility.violations).toEqual([]);
  });

  it("communicates denied recovery in words and returns to ready", async () => {
    const user = userEvent.setup();
    render(<InterfaceStateExplorer states={states} />);

    await user.click(screen.getByRole("button", { name: "Access unavailable" }));

    const deniedStatus = screen.getByRole("status");
    expect(deniedStatus).toHaveTextContent("You do not have access to this view");
    expect(deniedStatus).toHaveTextContent(
      "Return to a view already available to you.",
    );

    await user.click(screen.getByRole("button", { name: "Return to ready" }));
    expect(screen.getByRole("status")).toHaveTextContent("This view is up to date");
  });
});
