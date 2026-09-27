import type { Metadata } from "next";

import { AppShell } from "../../src/components/app-shell";
import { InstitutionalStructurePrototype } from "../../src/components/institutional-structure-prototype";
import { syntheticViewData } from "../../src/fixtures/synthetic-view-data";

export const metadata: Metadata = {
  title: "Institutional structure prototype",
};

export default async function InstitutionalStructurePage() {
  const viewData = await syntheticViewData.getInstitutionalStructure();

  return (
    <AppShell activePage="structure" context={viewData.context}>
      <InstitutionalStructurePrototype viewData={viewData} />
    </AppShell>
  );
}
