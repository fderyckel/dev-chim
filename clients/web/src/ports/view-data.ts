export type NavigationKey = "home" | "assignments" | "structure" | "preview";

export type PrototypeContext = Readonly<{
  experience: "ui0" | "ui1";
  tenantName: string;
  tenantKind: "synthetic";
  dateLabel: string;
  connectionLabel: string;
}>;

export type PriorityItem = Readonly<{
  eyebrow: string;
  title: string;
  description: string;
  actionLabel: string;
  actionHref: string;
}>;

export type AttentionItem = Readonly<{
  id: string;
  title: string;
  detail: string;
  status: string;
  tone: "attention" | "neutral";
}>;

export type ActivityItem = Readonly<{
  id: string;
  label: string;
  detail: string;
  time: string;
}>;

export type HomeViewData = Readonly<{
  context: PrototypeContext;
  priority: PriorityItem;
  attention: ReadonlyArray<AttentionItem>;
  activity: ReadonlyArray<ActivityItem>;
}>;

export type InterfaceStateKey =
  | "ready"
  | "loading"
  | "empty"
  | "denied"
  | "rate-limited"
  | "retryable"
  | "conflict"
  | "unexpected";

export type InterfaceState = Readonly<{
  key: InterfaceStateKey;
  label: string;
  title: string;
  description: string;
  recovery: string;
  tone: "positive" | "neutral" | "attention" | "critical";
}>;

export type PreviewViewData = Readonly<{
  context: PrototypeContext;
  states: ReadonlyArray<InterfaceState>;
}>;

export type InstitutionalUnitClassification = "institution" | "organizational_unit";

export type InstitutionalUnitNode = Readonly<{
  id: string;
  name: string;
  classification: InstitutionalUnitClassification;
  localLabel: string;
  code: string;
  status: "current" | "closed";
  children: ReadonlyArray<InstitutionalUnitNode>;
}>;

export type StructureRelationship = Readonly<{
  label: string;
  detail: string;
}>;

export type ReviewStructureNode = Readonly<{
  id: string;
  name: string;
  meaning: string;
  reference: string;
  status: "current" | "closed";
  children: ReadonlyArray<ReviewStructureNode>;
}>;

export type MoveImpact = Readonly<{
  meaning: string;
  outcome: "unchanged" | "requires_reconciliation" | "ready" | "blocks_move";
  detail: string;
}>;

export type OperatorTransferPreview = Readonly<{
  id: string;
  institution: string;
  from: string;
  to: string;
  effectiveOn: string;
  state: "blocked" | "ready_for_boundary_check";
  impacts: ReadonlyArray<MoveImpact>;
}>;

export type OperatorGovernanceStep = Readonly<{
  label: string;
  state: "complete" | "current" | "pending";
  detail: string;
}>;

export type AccountabilityAction = Readonly<{
  label: string;
  outcome: "continues" | "fails_closed";
  detail: string;
}>;

export type InstitutionalStructureViewData = Readonly<{
  context: PrototypeContext;
  linkedStructure: Readonly<{
    legalEntities: ReadonlyArray<ReviewStructureNode>;
    legalRelationships: ReadonlyArray<StructureRelationship>;
    corporateUnits: ReadonlyArray<ReviewStructureNode>;
    corporateOwner: string;
    responsibility: Readonly<{
      institution: string;
      primaryOperator: string;
      otherRelationships: ReadonlyArray<StructureRelationship>;
    }>;
    operatorTransferPreviews: ReadonlyArray<OperatorTransferPreview>;
    operatorGovernance: Readonly<{
      workflow: ReadonlyArray<OperatorGovernanceStep>;
      approvalPaths: ReadonlyArray<StructureRelationship>;
      evidence: Readonly<{
        type: string;
        source: string;
        reference: string;
        classification: string;
        verifiedOn: string;
      }>;
      accountabilityReview: Readonly<{
        institution: string;
        trigger: string;
        status: string;
        actions: ReadonlyArray<AccountabilityAction>;
        resolutionPaths: ReadonlyArray<string>;
      }>;
    }>;
  }>;
  roots: ReadonlyArray<InstitutionalUnitNode>;
  selectedUnit: Readonly<{
    id: string;
    name: string;
    classification: InstitutionalUnitClassification;
    localLabel: string;
    code: string;
    timeZone: string;
    status: "current" | "closed";
    currentParent: string;
    site: string;
  }>;
  sites: ReadonlyArray<StructureRelationship>;
  affiliations: ReadonlyArray<StructureRelationship>;
  movePreview: Readonly<{
    unit: string;
    from: string;
    to: string;
    impacts: ReadonlyArray<MoveImpact>;
  }>;
}>;

/**
 * UI-0's deliberately small, read-only boundary. It has no mutation method and
 * accepts no actor, tenant, capability, repository, placement, or routing input.
 */
export interface ViewDataPort {
  getHome(): Promise<HomeViewData>;
  getInstitutionalStructure(): Promise<InstitutionalStructureViewData>;
  getPreview(): Promise<PreviewViewData>;
}
