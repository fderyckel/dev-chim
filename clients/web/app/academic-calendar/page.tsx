import type { Metadata } from "next";

import { AppShell } from "../../src/components/app-shell";
import { AcademicCalendarPreparation } from "../../src/components/academic-calendar-preparation";
import { syntheticViewData } from "../../src/fixtures/synthetic-view-data";

export const metadata: Metadata = {
  title: "Academic calendar preview",
};

export default async function AcademicCalendarPage() {
  const viewData = await syntheticViewData.getAcademicCalendarPreparation();

  return (
    <AppShell activePage="calendar" context={viewData.context}>
      <AcademicCalendarPreparation viewData={viewData} />
    </AppShell>
  );
}
