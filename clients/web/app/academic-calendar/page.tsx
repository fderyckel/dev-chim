import type { Metadata } from "next";

import { AppShell } from "../../src/components/app-shell";
import { AcademicCalendarPreparation } from "../../src/components/academic-calendar-preparation";
import { syntheticViewData } from "../../src/fixtures/synthetic-view-data";

export const metadata: Metadata = {
  title: "Academic calendar",
};

export default async function AcademicCalendarPage() {
  const viewData = await syntheticViewData.getAcademicCalendarPreparation();
  const connected = process.env.CHIMWEMWE_CLASSROOM_DEMO === "true";
  const context = connected
    ? {
        ...viewData.context,
        dateLabel: "Synthetic calendar qualification",
        connectionLabel: "Local synthetic session · authoritative core writer",
      }
    : viewData.context;

  return (
    <AppShell activePage="calendar" context={context} writerConnected={connected}>
      <AcademicCalendarPreparation connected={connected} viewData={viewData} />
    </AppShell>
  );
}
