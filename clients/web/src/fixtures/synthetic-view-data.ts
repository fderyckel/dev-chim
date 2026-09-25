import type {
  HomeViewData,
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

assertSyntheticExperienceIsExplicitlyEnabled();

export const syntheticViewData: ViewDataPort = {
  async getHome() {
    return home;
  },
  async getPreview() {
    return preview;
  },
};
