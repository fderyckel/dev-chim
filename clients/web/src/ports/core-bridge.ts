import type { components } from "../generated/ui1/schema";

type AssignmentOptionSchema = components["schemas"]["AssignmentOption"];
type AssignmentOptionsSchema = components["schemas"]["AssignmentOptionsData"];

export type AssignmentOption = Readonly<{
  id: AssignmentOptionSchema["id"];
  label: AssignmentOptionSchema["label"];
}>;

export type AssignmentOptionsData = Readonly<{
  connection: AssignmentOptionsSchema["connection"];
  contract_version: AssignmentOptionsSchema["contract_version"];
  memberships: ReadonlyArray<AssignmentOption>;
  roles: ReadonlyArray<AssignmentOption>;
}>;

export type CoreBridgeFailure = Readonly<{
  state: "disabled" | "denied" | "retryable" | "unavailable" | "unexpected";
  reference?: string;
}>;

export type CoreBridgeResult =
  Readonly<{ state: "ready"; data: AssignmentOptionsData }> | CoreBridgeFailure;
