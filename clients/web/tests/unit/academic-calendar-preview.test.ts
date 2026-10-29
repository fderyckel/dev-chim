import { describe, expect, it } from "vitest";

import {
  prepareCalendarPreview,
  resolveCalendarDate,
} from "../../src/lib/academic-calendar-preview";
import type { AcademicCalendarDraft } from "../../src/ports/view-data";

const calendar: AcademicCalendarDraft = {
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
    {
      id: "closure-2",
      label: "Year-end break",
      date: "2026-12-23",
      reasonKey: "year_end_break",
    },
  ],
};

describe("the local academic-calendar preview", () => {
  it("calculates term dates and resolves weekdays, closures, weekends, and gaps", () => {
    const result = prepareCalendarPreview(calendar);

    expect(result.ok).toBe(true);
    if (!result.ok) return;

    expect(result.preview.instructionalDateCount).toBe(201);
    expect(resolveCalendarDate(result.preview, "2026-09-07")).toMatchObject({
      status: "instructional",
      reason: "instructional_weekday",
      periodLabel: "Term 1",
    });
    expect(resolveCalendarDate(result.preview, "2026-10-15")).toMatchObject({
      status: "non_instructional",
      reason: "closure",
      closureLabel: "Mothers' Day",
    });
    expect(resolveCalendarDate(result.preview, "2026-10-24")).toMatchObject({
      status: "non_instructional",
      reason: "ordinary_weekday_off",
    });
    expect(resolveCalendarDate(result.preview, "2026-12-28")).toEqual({
      status: "non_instructional",
      reason: "outside_period",
    });
  });

  it("refuses overlapping terms, duplicate closures, and an empty weekday pattern", () => {
    const result = prepareCalendarPreview({
      ...calendar,
      instructionalWeekdays: [],
      periods: [calendar.periods[0], { ...calendar.periods[1], startOn: "2026-12-18" }],
      closures: [
        calendar.closures[0],
        { ...calendar.closures[1], date: calendar.closures[0].date },
      ],
    });

    expect(result.ok).toBe(false);
    if (result.ok) return;

    expect(result.errors).toEqual(
      expect.arrayContaining([
        "Choose at least one distinct instructional weekday.",
        "Term dates must not overlap.",
        "Two closures cannot use the same date.",
      ]),
    );
  });
});
