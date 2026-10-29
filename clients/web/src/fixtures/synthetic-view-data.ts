import type {
  AcademicCalendarPreparationViewData,
  HomeViewData,
  InstitutionalStructureViewData,
  PreviewViewData,
  PrototypeContext,
  ViewDataPort,
} from "../ports/view-data";

function assertSyntheticExperienceIsExplicitlyEnabled(): void {
  if (process.env.CHIMWEMWE_UI0_SYNTHETIC !== "true") {
    throw new Error(
      "UI-0 synthetic data is disabled. Set CHIMWEMWE_UI0_SYNTHETIC=true only for the local prototype.",
    );
  }
}

const context: PrototypeContext = {
  experience: "ui0",
  tenantName: "Mphamvu Learning Community",
  tenantKind: "synthetic",
  dateLabel: "Example day · 21 September 2026",
  connectionLabel: "Local fixture · no server connection",
};

const academicCalendarPreparation: AcademicCalendarPreparationViewData = {
  context,
  institution: {
    id: "30000000-0000-4000-8000-000000000001",
    label: "Nthambi Primary and Early Years School",
  },
  calendar: {
    label: "Academic year 2026–2027",
    code: "AY_2026_27",
    startOn: "2026-09-01",
    endOn: "2027-06-30",
    timeZone: "Africa/Blantyre",
    instructionalWeekdays: [1, 2, 3, 4, 5],
    periods: [
      {
        id: "44444444-4444-4444-8444-444444444444",
        label: "Term 1",
        sequence: 1,
        startOn: "2026-09-01",
        endOn: "2026-12-18",
      },
      {
        id: "55555555-5555-4555-8555-555555555555",
        label: "Term 2",
        sequence: 2,
        startOn: "2027-01-11",
        endOn: "2027-06-30",
      },
    ],
    closures: [
      {
        id: "66666666-6666-4666-8666-666666666666",
        label: "Mothers' Day",
        date: "2026-10-15",
        reasonKey: "public_holiday",
      },
      {
        id: "77777777-7777-4777-8777-777777777777",
        label: "Year-end break",
        date: "2026-12-23",
        reasonKey: "year_end_break",
      },
    ],
  },
  initialResolutionDate: "2026-10-15",
};

const home: HomeViewData = {
  context,
  priority: {
    eyebrow: "Suggested next step",
    title: "Review today’s three attention items",
    description:
      "Start with the examples that need a person’s judgement. Nothing in this prototype can change a school record.",
    actionLabel: "Review attention items",
    actionHref: "#attention",
  },
  attention: [
    {
      id: "example-attention-01",
      title: "Morning register needs context",
      detail: "Three synthetic entries are incomplete and ready for review.",
      status: "3 examples",
      tone: "attention",
    },
    {
      id: "example-attention-02",
      title: "Family update is waiting",
      detail: "One example message needs a final clarity check.",
      status: "1 example",
      tone: "neutral",
    },
    {
      id: "example-attention-03",
      title: "Import check is complete",
      detail: "The synthetic preview has no unresolved validation messages.",
      status: "Ready",
      tone: "neutral",
    },
  ],
  activity: [
    {
      id: "example-activity-01",
      label: "Example register reviewed",
      detail: "Synthetic activity · no record was changed",
      time: "09:24",
    },
    {
      id: "example-activity-02",
      label: "Example note prepared",
      detail: "Synthetic activity · local fixture only",
      time: "08:50",
    },
    {
      id: "example-activity-03",
      label: "Prototype opened",
      detail: "Local browser session",
      time: "08:32",
    },
  ],
};

const preview: PreviewViewData = {
  context,
  states: [
    {
      key: "ready",
      label: "Ready",
      title: "This view is up to date",
      description: "The latest synthetic information is ready to review.",
      recovery: "No action is needed.",
      tone: "positive",
    },
    {
      key: "loading",
      label: "Loading",
      title: "Getting the latest view",
      description: "Keep this page open while the example content is prepared.",
      recovery: "If this takes too long, return to Home and try again.",
      tone: "neutral",
    },
    {
      key: "empty",
      label: "Empty",
      title: "Nothing to show yet",
      description: "No synthetic examples match this view.",
      recovery: "Return to Home or change the example filter.",
      tone: "neutral",
    },
    {
      key: "denied",
      label: "Access unavailable",
      title: "You do not have access to this view",
      description: "The interface does not reveal whether restricted content exists.",
      recovery: "Return to a view already available to you or ask for help.",
      tone: "critical",
    },
    {
      key: "rate-limited",
      label: "Too many requests",
      title: "Pause before trying again",
      description: "This synthetic example models a short request limit.",
      recovery: "Wait 30 seconds, then try again once.",
      tone: "attention",
    },
    {
      key: "retryable",
      label: "Temporarily unavailable",
      title: "The service cannot respond yet",
      description: "No change was attempted and no private detail is shown.",
      recovery: "Try again in a few minutes. Ask for help if it continues.",
      tone: "attention",
    },
    {
      key: "conflict",
      label: "Needs review",
      title: "This example changed elsewhere",
      description: "Your view is older than the current synthetic example.",
      recovery: "Review the latest version before making another decision.",
      tone: "attention",
    },
    {
      key: "unexpected",
      label: "Something went wrong",
      title: "This view could not be completed",
      description: "No change was made. A reference can be shared with support.",
      recovery: "Return to Home and try again. Ask for help if it repeats.",
      tone: "critical",
    },
  ],
};

const institutionalStructure: InstitutionalStructureViewData = {
  context,
  linkedStructure: {
    legalEntities: [
      {
        id: "71000000-0000-4000-8000-000000000001",
        name: "Mphamvu Learning Holdings",
        meaning: "Legal entity · consolidation parent",
        reference: "Synthetic registration GRP-001",
        status: "current",
        children: [
          {
            id: "71000000-0000-4000-8000-000000000002",
            name: "Mphamvu Education Operations",
            meaning: "Legal entity · education operator",
            reference: "Synthetic registration OPS-002",
            status: "current",
            children: [],
          },
          {
            id: "71000000-0000-4000-8000-000000000003",
            name: "Mphamvu Property Foundation",
            meaning: "Legal entity · property owner",
            reference: "Synthetic registration PROP-003",
            status: "current",
            children: [],
          },
        ],
      },
      {
        id: "71000000-0000-4000-8000-000000000004",
        name: "Community Education Trust",
        meaning: "Legal entity · outside consolidation tree",
        reference: "Synthetic registration CET-004",
        status: "current",
        children: [],
      },
    ],
    legalRelationships: [
      {
        label: "Joint control of Mphamvu Education Operations",
        detail:
          "Mphamvu Learning Holdings and Community Education Trust have separate typed control relationships. Only the holdings entity is the consolidation parent.",
      },
    ],
    corporateUnits: [
      {
        id: "72000000-0000-4000-8000-000000000001",
        name: "Shared Services Centre",
        meaning: "Corporate unit",
        reference: "SSC",
        status: "current",
        children: [
          {
            id: "72000000-0000-4000-8000-000000000002",
            name: "Finance Operations",
            meaning: "Corporate unit",
            reference: "SSC-FIN",
            status: "current",
            children: [],
          },
          {
            id: "72000000-0000-4000-8000-000000000003",
            name: "People and Safeguarding",
            meaning: "Corporate unit",
            reference: "SSC-PS",
            status: "current",
            children: [],
          },
        ],
      },
    ],
    corporateOwner: "Mphamvu Education Operations",
    responsibility: {
      institution: "Mphamvu University",
      primaryOperator: "Mphamvu Education Operations",
      otherRelationships: [
        {
          label: "Property owner · City Learning Centre",
          detail:
            "Mphamvu Property Foundation owns the site. Site ownership is not educational parentage or operating authority.",
        },
        {
          label: "Additional joint-control evidence",
          detail:
            "Community Education Trust is recorded through a separate legal relationship; it is not a second primary operator.",
        },
      ],
    },
    operatorTransferPreviews: [
      {
        id: "operator-transfer-blocked",
        institution: "Lusungu Community College",
        from: "Mphamvu Education Operations",
        to: "Community Education Trust",
        effectiveOn: "1 January 2027 · Africa/Blantyre",
        state: "blocked",
        impacts: [
          {
            meaning: "Educational identity and containment",
            outcome: "unchanged",
            detail:
              "The institution keeps its stable identity and educational parentage.",
          },
          {
            meaning: "Finance, contracts, and employment",
            outcome: "requires_reconciliation",
            detail:
              "Each owning contract must reconcile its records; nothing is inherited from the operator link.",
          },
          {
            meaning: "Authorization and placement",
            outcome: "unchanged",
            detail:
              "Capabilities, data access, modules, and tenant placement remain independent.",
          },
          {
            meaning: "Unclassified safeguarding integration",
            outcome: "blocks_move",
            detail:
              "The transfer remains unavailable until the integration owner classifies the effect.",
          },
        ],
      },
      {
        id: "operator-transfer-ready",
        institution: "Mwayi Combined School",
        from: "Mphamvu Education Operations",
        to: "Community Education Trust",
        effectiveOn: "1 January 2027 · Africa/Blantyre",
        state: "ready_for_boundary_check",
        impacts: [
          {
            meaning: "Approval and verified evidence",
            outcome: "ready",
            detail:
              "A distinct eligible approver accepted the proposal after the evidence reference was verified.",
          },
          {
            meaning: "Finance, contracts, and employment",
            outcome: "ready",
            detail:
              "The owning domains recorded their reconciliation outcomes without rewriting historical records.",
          },
          {
            meaning: "Authorization and placement",
            outcome: "unchanged",
            detail:
              "Capabilities, data access, modules, and tenant placement remain independent.",
          },
          {
            meaning: "Effective-boundary check",
            outcome: "requires_reconciliation",
            detail:
              "The named activation action must revalidate evidence and conflicts on the effective date before it can activate.",
          },
        ],
      },
    ],
    operatorGovernance: {
      workflow: [
        {
          label: "Proposed",
          state: "complete",
          detail:
            "The proposed operator, effective date, institution-local time zone, reason, and evidence reference are recorded.",
        },
        {
          label: "Evidence verified",
          state: "complete",
          detail:
            "An eligible reviewer verified the protected source; the prototype stores metadata, not a duplicate document.",
        },
        {
          label: "Approved",
          state: "complete",
          detail:
            "A distinct eligible approver accepted the transfer under the normal control path.",
        },
        {
          label: "Effective-boundary revalidation",
          state: "current",
          detail:
            "The future-effective transfer waits for a named action to recheck evidence, conflicts, and operator continuity.",
        },
        {
          label: "Active",
          state: "pending",
          detail:
            "Activation records both the intended institution-local effective date and the actual recorded time.",
        },
      ],
      approvalPaths: [
        {
          label: "Normal path · distinct approver",
          detail:
            "The proposer and final approver are different eligible people. Approval alone does not activate a future transfer.",
        },
        {
          label: "Governed single-controller exception",
          detail:
            "Only an explicit policy may allow one controller to propose and approve. It requires stronger assurance, a reason and verified evidence, a visible exception marker, and retrospective review.",
        },
      ],
      evidence: {
        type: "Operator appointment instrument",
        source: "Protected governance record",
        reference: "Synthetic evidence GOV-2026-014",
        classification: "Restricted governance evidence",
        verifiedOn: "18 September 2026",
      },
      accountabilityReview: {
        institution: "Chisomo Secondary School",
        trigger:
          "Previously verified operator evidence was later invalidated after the assignment became effective.",
        status: "Legal accountability under review",
        actions: [
          {
            label: "Attendance, safeguarding, and teaching continuity",
            outcome: "continues",
            detail:
              "Essential learner-facing work continues unless a separate policy explicitly requires suspension.",
          },
          {
            label: "Operator-dependent finance or legal action",
            outcome: "fails_closed",
            detail:
              "Actions whose validity depends on the operator are unavailable while accountability is unresolved.",
          },
          {
            label: "Unknown dependency",
            outcome: "fails_closed",
            detail:
              "An action with no declared dependency classification cannot proceed by default.",
          },
        ],
        resolutionPaths: [
          "Reverify the existing evidence",
          "Complete an approved operator transfer",
          "Apply a governed temporal correction under ADR 0018",
          "Use a separately governed suspension or closure action",
        ],
      },
    },
  },
  roots: [
    {
      id: "30000000-0000-4000-8000-000000000001",
      name: "Nthambi Primary and Early Years School",
      classification: "institution",
      localLabel: "Primary / early years",
      code: "NPES",
      status: "current",
      children: [
        {
          id: "30000000-0000-4000-8000-000000000011",
          name: "Early Years",
          classification: "organizational_unit",
          localLabel: "Early years",
          code: "NPES-EY",
          status: "current",
          children: [],
        },
        {
          id: "30000000-0000-4000-8000-000000000012",
          name: "Primary School",
          classification: "organizational_unit",
          localLabel: "Primary section",
          code: "NPES-PRI",
          status: "current",
          children: [],
        },
      ],
    },
    {
      id: "40000000-0000-4000-8000-000000000001",
      name: "Chisomo Secondary School",
      classification: "institution",
      localLabel: "Secondary school",
      code: "CSS",
      status: "current",
      children: [],
    },
    {
      id: "50000000-0000-4000-8000-000000000001",
      name: "Mwayi Combined School",
      classification: "institution",
      localLabel: "Combined formal education",
      code: "MCS",
      status: "current",
      children: [
        {
          id: "50000000-0000-4000-8000-000000000011",
          name: "Primary Section",
          classification: "organizational_unit",
          localLabel: "Primary section",
          code: "MCS-PRI",
          status: "current",
          children: [],
        },
        {
          id: "50000000-0000-4000-8000-000000000012",
          name: "Secondary Section",
          classification: "organizational_unit",
          localLabel: "Secondary section",
          code: "MCS-SEC",
          status: "current",
          children: [],
        },
      ],
    },
    {
      id: "20000000-0000-4000-8000-000000000001",
      name: "Lusungu Community College",
      classification: "institution",
      localLabel: "College / community college",
      code: "LCC",
      status: "current",
      children: [],
    },
    {
      id: "10000000-0000-4000-8000-000000000001",
      name: "Mphamvu University",
      classification: "institution",
      localLabel: "University",
      code: "MU",
      status: "current",
      children: [
        {
          id: "10000000-0000-4000-8000-000000000011",
          name: "School of Learning Sciences",
          classification: "organizational_unit",
          localLabel: "School",
          code: "MU-LS",
          status: "current",
          children: [
            {
              id: "10000000-0000-4000-8000-000000000111",
              name: "Department of Inclusive Education",
              classification: "organizational_unit",
              localLabel: "Department",
              code: "MU-LS-IE",
              status: "current",
              children: [
                {
                  id: "10000000-0000-4000-8000-000000001111",
                  name: "Inclusive Education Practice Centre",
                  classification: "organizational_unit",
                  localLabel: "Centre",
                  code: "MU-LS-IE-PC",
                  status: "current",
                  children: [],
                },
              ],
            },
          ],
        },
        {
          id: "10000000-0000-4000-8000-000000000012",
          name: "School of Community Education",
          classification: "organizational_unit",
          localLabel: "School",
          code: "MU-CE",
          status: "current",
          children: [],
        },
        {
          id: "10000000-0000-4000-8000-000000000013",
          name: "Former Foundation Studies Unit",
          classification: "organizational_unit",
          localLabel: "Department",
          code: "MU-FS",
          status: "closed",
          children: [],
        },
      ],
    },
  ],
  selectedUnit: {
    id: "10000000-0000-4000-8000-000000000111",
    name: "Department of Inclusive Education",
    classification: "organizational_unit",
    localLabel: "Department",
    code: "MU-LS-IE",
    timeZone: "Africa/Blantyre",
    status: "current",
    currentParent: "School of Learning Sciences",
    site: "City Learning Centre",
  },
  sites: [
    {
      label: "City Learning Centre",
      detail:
        "Shared by Mphamvu University and Lusungu Community College; it is not either institution's parent.",
    },
    {
      label: "Riverside Early Learning Site",
      detail:
        "Associated with Nthambi Primary and Early Years School through a separate site relationship.",
    },
  ],
  affiliations: [
    {
      label: "Joint teacher-education programme",
      detail:
        "Connects the selected department and Lusungu Community College without adding a second canonical parent.",
    },
  ],
  movePreview: {
    unit: "Department of Inclusive Education",
    from: "School of Learning Sciences",
    to: "School of Community Education",
    impacts: [
      {
        meaning: "Authorization",
        outcome: "unchanged",
        detail: "Parentage grants no capability or descendant record access.",
      },
      {
        meaning: "Reporting",
        outcome: "requires_reconciliation",
        detail:
          "One explicit descendant-scope report must be recalculated before the move.",
      },
      {
        meaning: "Calendar and configuration",
        outcome: "unchanged",
        detail: "No live parent inheritance exists; explicit adoptions remain pinned.",
      },
      {
        meaning: "Module activation and placement",
        outcome: "unchanged",
        detail:
          "Tenant lifecycle and placement are independent of the institutional tree.",
      },
      {
        meaning: "Unregistered downstream consumer",
        outcome: "blocks_move",
        detail: "The move remains unavailable until every effect is classified.",
      },
    ],
  },
};

assertSyntheticExperienceIsExplicitlyEnabled();

export const syntheticViewData: ViewDataPort = {
  async getAcademicCalendarPreparation() {
    return academicCalendarPreparation;
  },
  async getHome() {
    return home;
  },
  async getInstitutionalStructure() {
    return institutionalStructure;
  },
  async getPreview() {
    return preview;
  },
};
