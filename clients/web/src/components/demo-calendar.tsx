"use client";

import type { DemoInstance } from "../ports/demo-instance";
import type {
  ModelViewRecord,
  ModelViewSetDefinition,
} from "../model-views/model-view-contract";
import { ModelViewWorkspace } from "../model-views/model-view-workspace";

const definition = {
  schemaVersion: 1,
  sourceRef: "demo.calendar.entries",
  title: "Calendar entries",
  identityField: "id",
  fields: [
    { ref: "id", label: "Identity", type: "text" },
    { ref: "title", label: "Name", type: "text" },
    { ref: "type", label: "Type", type: "status" },
    { ref: "scope", label: "Scope", type: "text" },
    { ref: "start_on", label: "Starts", type: "date" },
    { ref: "end_on", label: "Ends · inclusive", type: "date" },
  ],
  views: [
    {
      kind: "calendar",
      titleField: "title",
      startField: "start_on",
      endField: "end_on",
      statusField: "type",
      scopeField: "scope",
      contextStatuses: ["Teaching period"],
    },
    { kind: "list", fields: ["title", "type", "start_on", "end_on", "scope"] },
  ],
  defaultView: "calendar",
} as const satisfies ModelViewSetDefinition;

export function DemoCalendar({ data }: { data: DemoInstance }) {
  const records: ModelViewRecord[] = (
    [
      ["period", "Teaching period", data.terms],
      ["closure", "Student closure", data.closures],
      ["event", "Event · information only", data.events],
    ] as const
  ).flatMap(([kind, type, items]) =>
    items.map((item) => ({
      id: `${kind}.${item.id}`,
      title: item.label,
      type,
      scope: item.scope,
      start_on: item.from,
      end_on: item.through,
    })),
  );
  const weekdays = data.instructionalWeekdays
    .map((day) =>
      new Intl.DateTimeFormat(data.locale, {
        weekday: "short",
        timeZone: "UTC",
      }).format(new Date(Date.UTC(2026, 10, 1 + (day % 7)))),
    )
    .join(", ");
  return (
    <>
      <p className="c-demo-muted">
        {data.yearLabel} · Configured instructional weekdays: {weekdays}. Events do not
        change teaching days.
      </p>
      <ModelViewWorkspace
        definition={definition}
        records={records}
        calendarContext={{
          sourceKey: `${data.institutionId}.${data.academicYearId}`,
          referenceDate: data.referenceDate,
          referenceLabel: "Example date",
          coverageStart: data.yearStart,
          coverageEnd: data.yearEnd,
          scopeLabel: `${data.institution} · ${data.yearLabel}`,
          timeZone: data.timeZone,
          locale: data.locale,
          weekStartsOn: data.locale === "en-US" ? 0 : 1,
        }}
      />
    </>
  );
}
