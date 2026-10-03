import type {
  AcademicCalendarClosure,
  AcademicCalendarDraft,
  AcademicCalendarPeriod,
} from "../ports/view-data";

const millisecondsPerDay = 86_400_000;
const isoDatePattern = /^(\d{4})-(\d{2})-(\d{2})$/;

type ValidatedPeriod = AcademicCalendarPeriod &
  Readonly<{ startDay: number; endDay: number }>;

type ValidatedClosure = AcademicCalendarClosure & Readonly<{ day: number }>;

export type CalendarPreview = Readonly<{
  definition: AcademicCalendarDraft;
  instructionalDates: ReadonlyArray<string>;
  instructionalDateCount: number;
  periods: ReadonlyArray<ValidatedPeriod>;
  closures: ReadonlyArray<ValidatedClosure>;
  yearStartDay: number;
  yearEndDay: number;
}>;

export type CalendarPreparationResult =
  | Readonly<{ ok: true; preview: CalendarPreview }>
  | Readonly<{ ok: false; errors: ReadonlyArray<string> }>;

export type CalendarDateResolution = Readonly<{
  status: "instructional" | "non_instructional" | "outside_year";
  reason:
    | "instructional_weekday"
    | "ordinary_weekday_off"
    | "closure"
    | "outside_period"
    | "outside_year";
  periodLabel?: string;
  closureLabel?: string;
}>;

function parseIsoDate(value: string): number | null {
  const match = isoDatePattern.exec(value);
  if (!match) return null;

  const [, yearText, monthText, dayText] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const timestamp = Date.UTC(year, month - 1, day);
  const parsed = new Date(timestamp);

  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    return null;
  }

  return timestamp / millisecondsPerDay;
}

function toIsoDate(day: number): string {
  return new Date(day * millisecondsPerDay).toISOString().slice(0, 10);
}

function isoWeekday(day: number): number {
  return ((new Date(day * millisecondsPerDay).getUTCDay() + 6) % 7) + 1;
}

function contained(day: number, startDay: number, endDay: number): boolean {
  return day >= startDay && day <= endDay;
}

export function prepareCalendarPreview(
  definition: AcademicCalendarDraft,
): CalendarPreparationResult {
  const errors: string[] = [];
  const yearStartDay = parseIsoDate(definition.startOn);
  const yearEndDay = parseIsoDate(definition.endOn);

  if (!definition.label.trim()) errors.push("Give the academic year a label.");
  if (!definition.code.trim()) errors.push("Give the academic year a code.");
  if (!definition.timeZone.trim()) errors.push("Choose an explicit time zone.");
  if (yearStartDay === null || yearEndDay === null) {
    errors.push("Enter valid academic-year start and end dates.");
  } else if (yearStartDay > yearEndDay) {
    errors.push("The academic year must end on or after its start date.");
  } else if (yearEndDay - yearStartDay + 1 > 731) {
    errors.push("The academic year cannot span more than 731 dates.");
  }

  const uniqueWeekdays = new Set(definition.instructionalWeekdays);
  if (
    definition.instructionalWeekdays.length === 0 ||
    uniqueWeekdays.size !== definition.instructionalWeekdays.length ||
    definition.instructionalWeekdays.some((day) => day < 1 || day > 7)
  ) {
    errors.push("Choose at least one distinct instructional weekday.");
  }

  if (definition.periods.length === 0) errors.push("Add at least one term.");

  const periods: ValidatedPeriod[] = [];
  for (const period of definition.periods) {
    const startDay = parseIsoDate(period.startOn);
    const endDay = parseIsoDate(period.endOn);

    if (!period.label.trim()) {
      errors.push(`Term ${period.sequence} needs a label.`);
    }
    if (startDay === null || endDay === null || startDay > endDay) {
      errors.push(
        `${period.label || `Term ${period.sequence}`} needs a valid date range.`,
      );
      continue;
    }
    if (
      yearStartDay !== null &&
      yearEndDay !== null &&
      (!contained(startDay, yearStartDay, yearEndDay) ||
        !contained(endDay, yearStartDay, yearEndDay))
    ) {
      errors.push(
        `${period.label || `Term ${period.sequence}`} must stay inside the academic year.`,
      );
    }
    periods.push({ ...period, startDay, endDay });
  }

  const orderedPeriods = [...periods].sort(
    (left, right) => left.startDay - right.startDay,
  );
  for (let index = 1; index < orderedPeriods.length; index += 1) {
    if (orderedPeriods[index - 1].endDay >= orderedPeriods[index].startDay) {
      errors.push("Term dates must not overlap.");
      break;
    }
  }

  const closures: ValidatedClosure[] = [];
  const closureDates = new Set<string>();
  for (const closure of definition.closures) {
    const day = parseIsoDate(closure.date);
    if (!closure.label.trim()) errors.push("Every closure needs a label.");
    if (day === null) {
      errors.push(`${closure.label || "A closure"} needs a valid date.`);
      continue;
    }
    if (
      yearStartDay !== null &&
      yearEndDay !== null &&
      !contained(day, yearStartDay, yearEndDay)
    ) {
      errors.push(
        `${closure.label || "A closure"} must stay inside the academic year.`,
      );
    }
    if (closureDates.has(closure.date)) {
      errors.push("Two closures cannot use the same date.");
    }
    closureDates.add(closure.date);
    closures.push({ ...closure, day });
  }

  if (errors.length > 0 || yearStartDay === null || yearEndDay === null) {
    return { ok: false, errors: [...new Set(errors)] };
  }

  const closureDays = new Set(closures.map((closure) => closure.day));
  const instructionalDates: string[] = [];
  for (const period of periods) {
    for (let day = period.startDay; day <= period.endDay; day += 1) {
      if (uniqueWeekdays.has(isoWeekday(day)) && !closureDays.has(day)) {
        instructionalDates.push(toIsoDate(day));
      }
    }
  }

  const normalizedDates = [...new Set(instructionalDates)].sort();
  return {
    ok: true,
    preview: {
      definition,
      instructionalDates: normalizedDates,
      instructionalDateCount: normalizedDates.length,
      periods: [...periods].sort((left, right) => left.sequence - right.sequence),
      closures: [...closures].sort((left, right) => left.day - right.day),
      yearStartDay,
      yearEndDay,
    },
  };
}

export function resolveCalendarDate(
  preview: CalendarPreview,
  value: string,
): CalendarDateResolution {
  const day = parseIsoDate(value);
  if (day === null || !contained(day, preview.yearStartDay, preview.yearEndDay)) {
    return { status: "outside_year", reason: "outside_year" };
  }

  const closure = preview.closures.find((item) => item.day === day);
  const period = preview.periods.find((item) =>
    contained(day, item.startDay, item.endDay),
  );

  if (closure) {
    return {
      status: "non_instructional",
      reason: "closure",
      closureLabel: closure.label,
      periodLabel: period?.label,
    };
  }
  if (!period) return { status: "non_instructional", reason: "outside_period" };
  if (!preview.definition.instructionalWeekdays.includes(isoWeekday(day))) {
    return {
      status: "non_instructional",
      reason: "ordinary_weekday_off",
      periodLabel: period.label,
    };
  }
  return {
    status: "instructional",
    reason: "instructional_weekday",
    periodLabel: period.label,
  };
}
