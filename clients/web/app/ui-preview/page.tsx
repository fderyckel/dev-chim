import type { Metadata } from "next";

import { AppShell } from "../../src/components/app-shell";
import { UiPreview } from "../../src/components/ui-preview";
import { syntheticViewData } from "../../src/fixtures/synthetic-view-data";

export const metadata: Metadata = {
  title: "UI preview",
};

export default async function UiPreviewPage() {
  const viewData = await syntheticViewData.getPreview();

  return (
    <AppShell activePage="preview" context={viewData.context}>
      <UiPreview viewData={viewData} />
    </AppShell>
  );
}
