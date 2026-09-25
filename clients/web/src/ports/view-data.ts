export type NavigationKey = "home" | "assignments" | "preview";

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

/**
 * UI-0's deliberately small, read-only boundary. It has no mutation method and
 * accepts no actor, tenant, capability, repository, placement, or routing input.
 */
export interface ViewDataPort {
  getHome(): Promise<HomeViewData>;
  getPreview(): Promise<PreviewViewData>;
}
