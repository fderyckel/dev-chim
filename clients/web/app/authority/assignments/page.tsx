import type { Metadata } from "next";
import { connection } from "next/server";

import { AppShell } from "../../../src/components/app-shell";
import { AssignmentPreparation } from "../../../src/components/assignment-preparation";
import { CoreBridgeStateView } from "../../../src/components/core-bridge-state";
import type { PrototypeContext } from "../../../src/ports/view-data";
import { getAssignmentOptions } from "../../../src/server/core-bridge";

export const metadata: Metadata = {
  title: "Prepare role assignment",
};

const context: PrototypeContext = {
  experience: "ui1",
  tenantName: "Mphamvu Learning Community",
  tenantKind: "synthetic",
  dateLabel: "Local qualification · synthetic records",
  connectionLabel: "Local core · read-only connection",
};

export default async function AssignmentPreparationPage() {
  await connection();
  const result = await getAssignmentOptions();

  return (
    <AppShell activePage="assignments" context={context}>
      {result.state === "ready" ? (
        <AssignmentPreparation data={result.data} />
      ) : (
        <CoreBridgeStateView result={result} />
      )}
    </AppShell>
  );
}
