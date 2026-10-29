import type {
  CalendarViewContext,
  CalendarViewDefinition,
  ModelViewRecord,
  ModelViewSetDefinition,
} from "./model-view-contract";
import { monthDays, parseLocalDate } from "./local-date";

export type CalendarEntry = Readonly<{
  id: string;
  title: string;
  start: number;
  end: number;
  from: string;
  through: string;
  status: string;
  scope: string;
  context: boolean;
  record: ModelViewRecord;
}>;

export function calendarEntries(
  definition: ModelViewSetDefinition,
  records: ReadonlyArray<ModelViewRecord>,
  view: CalendarViewDefinition,
): { entries: CalendarEntry[]; issues: string[] } {
  const entries: CalendarEntry[] = [];
  const issues: string[] = [];
  const identities = new Set<string>();
  for (const record of records) {
    const id = record[definition.identityField];
    const title = record[view.titleField];
    const from = record[view.startField];
    const through = view.endField ? record[view.endField] : from;
    const start = typeof from === "string" ? parseLocalDate(from) : null;
    const end = typeof through === "string" ? parseLocalDate(through) : null;
    const status = view.statusField ? record[view.statusField] : "";
    const scope = view.scopeField ? record[view.scopeField] : "";
    if (
      typeof id !== "string" ||
      !id.trim() ||
      identities.has(id) ||
      typeof title !== "string" ||
      !title.trim() ||
      typeof from !== "string" ||
      typeof through !== "string" ||
      start === null ||
      end === null ||
      end < start ||
      typeof status !== "string" ||
      typeof scope !== "string"
    ) {
      issues.push(
        "Calendar data contains an invalid date, identity, range or display field.",
      );
      continue;
    }
    identities.add(id);
    entries.push({
      id,
      title,
      from,
      through,
      start,
      end,
      status,
      scope,
      context: view.contextStatuses?.includes(status) ?? false,
      record,
    });
  }
  return {
    entries: entries.sort(
      (a, b) =>
        a.start - b.start || a.title.localeCompare(b.title) || a.id.localeCompare(b.id),
    ),
    issues: [...new Set(issues)],
  };
}

export function calendarContextIssues(context?: CalendarViewContext): string[] {
  if (!context) return [];
  const start = parseLocalDate(context.coverageStart);
  const end = parseLocalDate(context.coverageEnd);
  const reference = parseLocalDate(context.referenceDate);
  try {
    new Intl.DateTimeFormat(context.locale ?? "en-GB", {
      timeZone: context.timeZone,
    }).format();
  } catch {
    return ["Calendar locale or time zone is unavailable."];
  }
  return start === null ||
    end === null ||
    end < start ||
    reference === null ||
    !context.sourceKey.trim() ||
    !context.scopeLabel.trim() ||
    !context.referenceLabel.trim() ||
    !Number.isInteger(context.weekStartsOn ?? 1) ||
    (context.weekStartsOn ?? 1) < 0 ||
    (context.weekStartsOn ?? 1) > 6
    ? ["Calendar coverage or display context is unavailable."]
    : [];
}

export function entriesInMonth(
  entries: ReadonlyArray<CalendarEntry>,
  month: string,
  status = "",
) {
  const days = monthDays(month).filter((day): day is number => day !== null);
  const start = days[0];
  const end = days.at(-1);
  return start === undefined || end === undefined
    ? []
    : entries.filter(
        (entry) =>
          entry.start <= end &&
          entry.end >= start &&
          (!status || entry.status === status),
      );
}
