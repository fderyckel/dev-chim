import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { run as runAccessibilityScan } from "axe-core";
import { describe, expect, it } from "vitest";

import { AppShell } from "../../src/components/app-shell";
import { HomeView } from "../../src/components/home-view";
import { InstitutionalStructurePrototype } from "../../src/components/institutional-structure-prototype";
import { InterfaceStateExplorer } from "../../src/components/interface-state-explorer";
import type {
  HomeViewData,
  InstitutionalStructureViewData,
  InterfaceState,
  PrototypeContext,
} from "../../src/ports/view-data";

const context: PrototypeContext = {
  experience: "ui0",
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

const structure: InstitutionalStructureViewData = {
  context,
  linkedStructure: {
    legalEntities: [
      {
        id: "legal-parent",
        name: "Example Learning Holdings",
        meaning: "Legal entity · consolidation parent",
        reference: "REG-1",
        status: "current",
        children: [
          {
            id: "legal-operator",
            name: "Example Education Operations",
            meaning: "Legal entity · operator",
            reference: "REG-2",
            status: "current",
            children: [],
          },
        ],
      },
    ],
    legalRelationships: [
      {
        label: "Joint control",
        detail: "Recorded outside the consolidation tree.",
      },
    ],
    corporateUnits: [
      {
        id: "corporate-unit",
        name: "Example Shared Services",
        meaning: "Corporate unit",
        reference: "ESS",
        status: "current",
        children: [],
      },
    ],
    corporateOwner: "Example Education Operations",
    responsibility: {
      institution: "Example University",
      primaryOperator: "Example Education Operations",
      otherRelationships: [
        {
          label: "Property owner · Example site",
          detail: "Separate from operation and educational containment.",
        },
      ],
    },
    operatorTransferPreviews: [
      {
        id: "blocked-transfer",
        institution: "Example Early Learning Centre",
        from: "Example Education Operations",
        to: "Example Community Trust",
        effectiveOn: "1 January 2027 · Africa/Blantyre",
        state: "blocked",
        impacts: [
          {
            meaning: "Authorization",
            outcome: "unchanged",
            detail: "The operator link grants no access.",
          },
          {
            meaning: "Unknown integration",
            outcome: "blocks_move",
            detail: "The transfer remains unavailable.",
          },
        ],
      },
      {
        id: "ready-transfer",
        institution: "Example Combined School",
        from: "Example Education Operations",
        to: "Example Community Trust",
        effectiveOn: "1 January 2027 · Africa/Blantyre",
        state: "ready_for_boundary_check",
        impacts: [
          {
            meaning: "Verified prerequisites",
            outcome: "ready",
            detail: "Known prerequisites are satisfied.",
          },
        ],
      },
    ],
    operatorGovernance: {
      workflow: [
        {
          label: "Proposed",
          state: "complete",
          detail: "The intended transfer is recorded.",
        },
        {
          label: "Evidence verified",
          state: "complete",
          detail: "The protected source was verified.",
        },
        {
          label: "Approved",
          state: "complete",
          detail: "A distinct eligible approver accepted the transfer.",
        },
        {
          label: "Effective-boundary revalidation",
          state: "current",
          detail: "Facts must be rechecked at the effective boundary.",
        },
        {
          label: "Active",
          state: "pending",
          detail: "Activation has not happened.",
        },
      ],
      approvalPaths: [
        {
          label: "Normal path · distinct approver",
          detail: "The proposer and approver are different people.",
        },
        {
          label: "Governed single-controller exception",
          detail: "An explicit policy and retrospective review are required.",
        },
      ],
      evidence: {
        type: "Appointment instrument",
        source: "Protected record",
        reference: "GOV-1",
        classification: "Restricted",
        verifiedOn: "18 September 2026",
      },
      accountabilityReview: {
        institution: "Example Secondary School",
        trigger: "Previously verified evidence was invalidated.",
        status: "Legal accountability under review",
        actions: [
          {
            label: "Teaching continuity",
            outcome: "continues",
            detail: "Essential learner-facing work continues.",
          },
          {
            label: "Operator-dependent action",
            outcome: "fails_closed",
            detail: "The action is unavailable.",
          },
        ],
        resolutionPaths: ["Reverify evidence", "Complete an approved transfer"],
      },
    },
  },
  roots: [
    {
      id: "root-a",
      name: "Example University",
      classification: "institution",
      localLabel: "University",
      code: "EU",
      status: "current",
      children: [
        {
          id: "unit-a",
          name: "Example Department",
          classification: "organizational_unit",
          localLabel: "Department",
          code: "EU-ED",
          status: "current",
          children: [],
        },
      ],
    },
    {
      id: "root-b",
      name: "Example Early Learning Centre",
      classification: "institution",
      localLabel: "Early Learning Centre",
      code: "EELC",
      status: "current",
      children: [],
    },
    {
      id: "root-c",
      name: "Example Secondary School",
      classification: "institution",
      localLabel: "Secondary school",
      code: "ESS",
      status: "current",
      children: [],
    },
    {
      id: "root-d",
      name: "Example Combined School",
      classification: "institution",
      localLabel: "Combined formal education",
      code: "ECS",
      status: "current",
      children: [],
    },
    {
      id: "root-e",
      name: "Example Community College",
      classification: "institution",
      localLabel: "College / community college",
      code: "ECC",
      status: "current",
      children: [],
    },
  ],
  selectedUnit: {
    id: "unit-a",
    name: "Example Department",
    classification: "organizational_unit",
    localLabel: "Department",
    code: "EU-ED",
    timeZone: "Africa/Blantyre",
    status: "current",
    currentParent: "Example University",
    site: "Shared learning site",
  },
  sites: [
    {
      label: "Shared learning site",
      detail: "Serves both roots without becoming their parent.",
    },
  ],
  affiliations: [
    {
      label: "Joint programme",
      detail: "Connects units without creating another canonical parent.",
    },
  ],
  movePreview: {
    unit: "Example Department",
    from: "Example University",
    to: "Another reviewed unit",
    impacts: [
      {
        meaning: "Authorization",
        outcome: "unchanged",
        detail: "Parentage grants no access.",
      },
      {
        meaning: "Unknown consumer",
        outcome: "blocks_move",
        detail: "The move remains unavailable.",
      },
    ],
  },
};

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

  it("separates legal, corporate, educational, site, and authority meanings", async () => {
    render(
      <AppShell activePage="structure" context={context}>
        <InstitutionalStructurePrototype viewData={structure} />
      </AppShell>,
    );

    expect(
      screen.getByRole("heading", { level: 1, name: "Institutional structure" }),
    ).toBeVisible();
    expect(
      screen.getByRole("list", { name: "Institutional containment" }),
    ).toBeVisible();
    expect(screen.getByText("Separate structures")).toBeVisible();
    expect(screen.getByRole("heading", { name: "Legal entities" })).toBeVisible();
    expect(screen.getByRole("heading", { name: "Corporate units" })).toBeVisible();
    expect(screen.getByRole("heading", { name: "Legal responsibility" })).toBeVisible();
    expect(screen.getByText("Primary legal operator")).toBeVisible();
    expect(screen.getByText(/Consolidation is not ownership/)).toBeVisible();
    expect(screen.getByRole("heading", { name: "Transfer review path" })).toBeVisible();
    expect(screen.getByText("Governed single-controller exception")).toBeVisible();
    expect(
      screen.getByRole("heading", { name: "Five representative contexts" }),
    ).toBeVisible();
    expect(screen.getByRole("heading", { name: "Sites" })).toBeVisible();
    expect(screen.getByRole("heading", { name: "Affiliations" })).toBeVisible();
    expect(screen.getByText("Blocks move")).toBeVisible();
    expect(screen.getByText("Blocks transfer")).toBeVisible();
    expect(screen.getByText("Ready for boundary check")).toBeVisible();
    expect(
      screen.getByRole("heading", { name: "Legal accountability under review" }),
    ).toBeVisible();
    expect(screen.getByText("Unavailable")).toBeVisible();
    expect(screen.queryByRole("button")).not.toBeInTheDocument();

    const accessibility = await runAccessibilityScan(document.body, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(accessibility.violations).toEqual([]);
  });
});
