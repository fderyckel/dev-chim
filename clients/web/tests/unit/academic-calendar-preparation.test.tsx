import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { run as runAccessibilityScan } from "axe-core";
import { describe, expect, it } from "vitest";

import { AcademicCalendarPreparation } from "../../src/components/academic-calendar-preparation";
import type { AcademicCalendarPreparationViewData } from "../../src/ports/view-data";

const viewData: AcademicCalendarPreparationViewData = {
  context: {
    experience: "ui0",
    tenantName: "Synthetic Learning Community",
    tenantKind: "synthetic",
    dateLabel: "Example day",
    connectionLabel: "Local fixture · no server connection",
  },
  institution: { id: "institution-1", label: "Example Primary School" },
  calendar: {
    label: "Academic year 2026–2027",
    code: "AY_2026_27",
    startOn: "2026-09-01",
    endOn: "2027-06-30",
    timeZone: "Africa/Blantyre",
    instructionalWeekdays: [1, 2, 3, 4, 5],
    periods: [
      {
        id: "term-1",
        label: "Term 1",
        sequence: 1,
        startOn: "2026-09-01",
        endOn: "2026-12-18",
      },
      {
        id: "term-2",
        label: "Term 2",
        sequence: 2,
        startOn: "2027-01-11",
        endOn: "2027-06-30",
      },
    ],
    closures: [
      {
        id: "closure-1",
        label: "Mothers' Day",
        date: "2026-10-15",
        reasonKey: "public_holiday",
      },
    ],
  },
  initialResolutionDate: "2026-10-15",
};

describe("the academic-calendar preparation screen", () => {
  it("labels the unsaved boundary and previews an edited calendar", async () => {
    const user = userEvent.setup();
    render(
      <main>
        <AcademicCalendarPreparation viewData={viewData} />
      </main>,
    );

    expect(
      screen.getByRole("heading", { name: "Prepare an academic calendar" }),
    ).toBeVisible();
    expect(screen.getByText("Not saved")).toBeVisible();
    expect(screen.getByRole("tab", { name: "Calendar" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(screen.getByRole("button", { name: /15 Oct 2026/ })).toBeVisible();
    expect(screen.getByText("Named closure")).toBeVisible();
    expect(screen.getByText("Mothers' Day")).toBeVisible();

    await user.click(screen.getByRole("tab", { name: "Form" }));
    expect(screen.getAllByText("Mothers' Day")).toHaveLength(2);
    await user.clear(screen.getByLabelText("Term 2 Starts"));
    await user.type(screen.getByLabelText("Term 2 Starts"), "2026-12-18");
    await user.click(screen.getByRole("button", { name: "Preview calendar" }));

    expect(screen.getByRole("alert")).toHaveTextContent("Term dates must not overlap.");

    await user.click(screen.getByRole("button", { name: "Reset example" }));
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(screen.getByText("Preview current")).toBeVisible();

    const accessibility = await runAccessibilityScan(document.body, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(accessibility.violations).toEqual([]);
  });
});
