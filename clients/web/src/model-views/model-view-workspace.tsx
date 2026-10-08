"use client";

import {
  useId,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent,
  type ReactNode,
} from "react";

import {
  fieldDefinition,
  validateModelViewSet,
  viewDefinition,
  type CalendarViewDefinition,
  type FormViewDefinition,
  type GanttViewDefinition,
  type ListViewDefinition,
  type ModelViewKind,
  type ModelViewRecord,
  type ModelViewSetDefinition,
  type ModelViewValue,
} from "./model-view-contract";
import {
  addMonths,
  formatLocalDate,
  monthDays,
  monthKey,
  monthLabel,
  parseLocalDate,
  toIsoLocalDate,
} from "./local-date";

type WorkspaceProps = Readonly<{
  definition: ModelViewSetDefinition;
  records: ReadonlyArray<ModelViewRecord>;
  overrides?: Partial<Record<ModelViewKind, ReactNode>>;
  supplements?: Partial<Record<ModelViewKind, ReactNode>>;
  selectedDate?: string;
  onSelectDate?: (value: string) => void;
}>;

type DatedRecord = Readonly<{
  id: string;
  title: string;
  start: number;
  end: number;
  startValue: string;
  endValue: string;
  status?: string;
  group?: string;
}>;

const viewLabels: Record<ModelViewKind, string> = {
  calendar: "Calendar",
  list: "List",
  form: "Form",
  gantt: "Gantt",
};

function displayValue(value: ModelViewValue, type?: string): string {
  if (value === null) return "Not provided";
  if (type === "date" && typeof value === "string") return formatLocalDate(value);
  if (typeof value === "boolean") return value ? "Yes" : "No";
  return String(value);
}

function stringValue(record: ModelViewRecord, field: string): string | null {
  const value = record[field];
  return typeof value === "string" ? value : null;
}

function datedRecords(
  definition: ModelViewSetDefinition,
  records: ReadonlyArray<ModelViewRecord>,
  view: CalendarViewDefinition | GanttViewDefinition,
): ReadonlyArray<DatedRecord> {
  return records.flatMap((record) => {
    const id = stringValue(record, definition.identityField);
    const title = stringValue(record, view.titleField);
    const startValue = stringValue(record, view.startField);
    const endValue =
      view.kind === "calendar" && !view.endField
        ? startValue
        : stringValue(record, view.endField ?? view.startField);
    const start = startValue ? parseLocalDate(startValue) : null;
    const end = endValue ? parseLocalDate(endValue) : null;

    if (!id || !title || !startValue || !endValue || start === null || end === null) {
      return [];
    }

    return [
      {
        id,
        title,
        start,
        end,
        startValue,
        endValue,
        status:
          view.kind === "calendar" && view.statusField
            ? (stringValue(record, view.statusField) ?? undefined)
            : undefined,
        group:
          view.kind === "gantt" && view.groupField
            ? (stringValue(record, view.groupField) ?? undefined)
            : undefined,
      },
    ];
  });
}

function ModelListView({
  definition,
  records,
  view,
}: Readonly<{
  definition: ModelViewSetDefinition;
  records: ReadonlyArray<ModelViewRecord>;
  view: ListViewDefinition;
}>) {
  return (
    <div className="c-model-list">
      <table>
        <caption>{definition.title}</caption>
        <thead>
          <tr>
            {view.fields.map((fieldRef) => (
              <th scope="col" key={fieldRef}>
                {fieldDefinition(definition, fieldRef)?.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {records.map((record, index) => (
            <tr key={String(record[definition.identityField] ?? index)}>
              {view.fields.map((fieldRef) => (
                <td key={fieldRef}>
                  {displayValue(
                    record[fieldRef] ?? null,
                    fieldDefinition(definition, fieldRef)?.type,
                  )}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function ModelFormView({
  definition,
  records,
  view,
}: Readonly<{
  definition: ModelViewSetDefinition;
  records: ReadonlyArray<ModelViewRecord>;
  view: FormViewDefinition;
}>) {
  const record = records[0];
  if (!record) return <p className="c-model-view-empty">No record is available.</p>;

  return (
    <dl className="c-model-form" aria-label={`${definition.title} record`} role="group">
      {view.fields.map((fieldRef) => (
        <div key={fieldRef}>
          <dt>{fieldDefinition(definition, fieldRef)?.label}</dt>
          <dd>
            {displayValue(
              record[fieldRef] ?? null,
              fieldDefinition(definition, fieldRef)?.type,
            )}
          </dd>
        </div>
      ))}
    </dl>
  );
}

function ModelCalendarView({
  definition,
  records,
  view,
  selectedDate,
  onSelectDate,
}: Readonly<{
  definition: ModelViewSetDefinition;
  records: ReadonlyArray<ModelViewRecord>;
  view: CalendarViewDefinition;
  selectedDate?: string;
  onSelectDate?: (value: string) => void;
}>) {
  const events = useMemo(
    () => datedRecords(definition, records, view),
    [definition, records, view],
  );
  const earliest =
    events.length > 0 ? Math.min(...events.map((item) => item.start)) : null;
  const latest = events.length > 0 ? Math.max(...events.map((item) => item.end)) : null;
  const initialMonth =
    (selectedDate && monthKey(selectedDate)) ||
    (earliest === null ? null : monthKey(toIsoLocalDate(earliest))) ||
    "2026-01";
  const [visibleMonth, setVisibleMonth] = useState(initialMonth);
  const cells = monthDays(visibleMonth);
  const earliestMonth =
    earliest === null ? visibleMonth : toIsoLocalDate(earliest).slice(0, 7);
  const latestMonth =
    latest === null ? visibleMonth : toIsoLocalDate(latest).slice(0, 7);

  return (
    <section className="c-model-calendar" aria-label={`${definition.title} calendar`}>
      <header className="c-model-calendar__header">
        <button
          className="c-model-view-control"
          disabled={visibleMonth <= earliestMonth}
          onClick={() => setVisibleMonth(addMonths(visibleMonth, -1))}
          type="button"
        >
          Previous month
        </button>
        <h2>{monthLabel(visibleMonth)}</h2>
        <button
          className="c-model-view-control"
          disabled={visibleMonth >= latestMonth}
          onClick={() => setVisibleMonth(addMonths(visibleMonth, 1))}
          type="button"
        >
          Next month
        </button>
      </header>

      <div className="c-model-calendar__weekdays" aria-hidden="true">
        {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((day) => (
          <span key={day}>{day}</span>
        ))}
      </div>
      <div className="c-model-calendar__grid">
        {cells.map((day, index) => {
          if (day === null) {
            return <span className="c-model-calendar__blank" key={`blank-${index}`} />;
          }

          const value = toIsoLocalDate(day);
          const dayEvents = events.filter(
            (event) => event.start <= day && event.end >= day,
          );
          const announcedEvents = dayEvents.map((event) => event.title).join(", ");
          const visibleEvents = dayEvents.filter(
            (event) =>
              event.start === day ||
              event.end === event.start ||
              value === selectedDate,
          );

          return (
            <button
              aria-label={`${formatLocalDate(value)}${announcedEvents ? `, ${announcedEvents}` : ""}`}
              aria-pressed={value === selectedDate}
              className="c-model-calendar__day"
              data-has-events={dayEvents.length > 0 ? "true" : "false"}
              key={value}
              onClick={() => onSelectDate?.(value)}
              type="button"
            >
              <span className="c-model-calendar__date">{Number(value.slice(-2))}</span>
              {visibleEvents.slice(0, 2).map((event) => (
                <span className="c-model-calendar__event" key={event.id}>
                  {event.title}
                  {event.status ? ` · ${event.status}` : ""}
                </span>
              ))}
            </button>
          );
        })}
      </div>
    </section>
  );
}

function monthTicks(minimum: number, maximum: number): ReadonlyArray<number> {
  const ticks: number[] = [];
  let current = toIsoLocalDate(minimum).slice(0, 7);
  const end = toIsoLocalDate(maximum).slice(0, 7);

  for (let index = 0; current <= end && index < 36; index += 1) {
    const day = parseLocalDate(`${current}-01`);
    if (day !== null && day >= minimum) ticks.push(day);
    current = addMonths(current, 1);
  }
  return ticks;
}

function ModelGanttView({
  definition,
  records,
  view,
}: Readonly<{
  definition: ModelViewSetDefinition;
  records: ReadonlyArray<ModelViewRecord>;
  view: GanttViewDefinition;
}>) {
  const accessibilityId = useId();
  const events = datedRecords(definition, records, view);
  if (events.length === 0) {
    return <p className="c-model-view-empty">No dated records are available.</p>;
  }

  const minimum = Math.min(...events.map((item) => item.start));
  const maximum = Math.max(...events.map((item) => item.end));
  const span = Math.max(1, maximum - minimum + 1);
  const plotStart = 250;
  const plotWidth = 920;
  const rowHeight = 48;
  const chartTop = 54;
  const height = chartTop + events.length * rowHeight + 16;
  const ticks = monthTicks(minimum, maximum);

  return (
    <section className="c-model-gantt" aria-label={`${definition.title} Gantt`}>
      <svg
        aria-labelledby={`${accessibilityId}-title ${accessibilityId}-description`}
        className="c-model-gantt__chart"
        role="img"
        viewBox={`0 0 1200 ${height}`}
      >
        <title id={`${accessibilityId}-title`}>{definition.title} timeline</title>
        <desc id={`${accessibilityId}-description`}>
          Read-only date ranges. Exact dates follow the chart.
        </desc>
        {ticks.map((tick) => {
          const x = plotStart + ((tick - minimum) / span) * plotWidth;
          const value = toIsoLocalDate(tick);
          return (
            <g key={value}>
              <line
                className="c-model-gantt__gridline"
                x1={x}
                x2={x}
                y1="30"
                y2={height}
              />
              <text className="c-model-gantt__tick" x={x + 6} y="24">
                {monthLabel(value.slice(0, 7)).replace(/\s\d{4}$/, "")}
              </text>
            </g>
          );
        })}
        {events.map((event, index) => {
          const y = chartTop + index * rowHeight;
          const x = plotStart + ((event.start - minimum) / span) * plotWidth;
          const width = Math.max(6, ((event.end - event.start + 1) / span) * plotWidth);
          return (
            <g key={event.id}>
              <text className="c-model-gantt__label" x="8" y={y + 20}>
                {event.title}
              </text>
              <rect
                className={
                  event.start === event.end
                    ? "c-model-gantt__bar c-model-gantt__bar--point"
                    : "c-model-gantt__bar"
                }
                height="24"
                rx="6"
                width={width}
                x={x}
                y={y + 4}
              />
            </g>
          );
        })}
      </svg>
      <ol aria-label="Exact Gantt dates" className="c-model-gantt__dates">
        {events.map((event) => (
          <li key={event.id}>
            <strong>{event.title}</strong>
            {event.group ? <span>{event.group}</span> : null}
            <span>
              {formatLocalDate(event.startValue)}
              {event.endValue === event.startValue
                ? ""
                : ` – ${formatLocalDate(event.endValue)}`}
            </span>
          </li>
        ))}
      </ol>
    </section>
  );
}

function DefaultView({
  definition,
  records,
  kind,
  selectedDate,
  onSelectDate,
}: Readonly<{
  definition: ModelViewSetDefinition;
  records: ReadonlyArray<ModelViewRecord>;
  kind: ModelViewKind;
  selectedDate?: string;
  onSelectDate?: (value: string) => void;
}>) {
  const view = viewDefinition(definition, kind);
  if (!view) return <p className="c-model-view-empty">This view is unavailable.</p>;

  switch (view.kind) {
    case "list":
      return <ModelListView definition={definition} records={records} view={view} />;
    case "form":
      return <ModelFormView definition={definition} records={records} view={view} />;
    case "calendar":
      return (
        <ModelCalendarView
          definition={definition}
          key={selectedDate ?? "calendar"}
          records={records}
          view={view}
          selectedDate={selectedDate}
          onSelectDate={onSelectDate}
        />
      );
    case "gantt":
      return <ModelGanttView definition={definition} records={records} view={view} />;
  }
}

export function ModelViewWorkspace({
  definition,
  records,
  overrides = {},
  supplements = {},
  selectedDate,
  onSelectDate,
}: WorkspaceProps) {
  const issues = validateModelViewSet(definition);
  const [activeView, setActiveView] = useState<ModelViewKind>(definition.defaultView);
  const tabRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const id = useId();

  function moveViewFocus(event: KeyboardEvent<HTMLButtonElement>, index: number) {
    let nextIndex: number | null = null;
    if (event.key === "ArrowRight") {
      nextIndex = (index + 1) % definition.views.length;
    } else if (event.key === "ArrowLeft") {
      nextIndex = (index - 1 + definition.views.length) % definition.views.length;
    } else if (event.key === "Home") {
      nextIndex = 0;
    } else if (event.key === "End") {
      nextIndex = definition.views.length - 1;
    }

    if (nextIndex === null) return;
    event.preventDefault();
    setActiveView(definition.views[nextIndex].kind);
    tabRefs.current[nextIndex]?.focus();
  }

  if (issues.length > 0) {
    return (
      <div className="c-model-view-error" role="alert">
        <strong>This view definition is unavailable.</strong>
        <ul>
          {issues.map((issue) => (
            <li key={issue}>{issue}</li>
          ))}
        </ul>
      </div>
    );
  }

  return (
    <section className="c-model-workspace" aria-label={`${definition.title} views`}>
      <div className="c-model-view-tabs" aria-label="Available views" role="tablist">
        {definition.views.map((view, index) => (
          <button
            aria-controls={`${id}-panel`}
            aria-selected={activeView === view.kind}
            className="c-model-view-tabs__tab"
            id={`${id}-${view.kind}`}
            key={view.kind}
            onClick={() => setActiveView(view.kind)}
            onKeyDown={(event) => moveViewFocus(event, index)}
            ref={(node) => {
              tabRefs.current[index] = node;
            }}
            role="tab"
            tabIndex={activeView === view.kind ? 0 : -1}
            type="button"
          >
            {viewLabels[view.kind]}
          </button>
        ))}
      </div>
      <div
        aria-labelledby={`${id}-${activeView}`}
        className="c-model-workspace__panel"
        id={`${id}-panel`}
        role="tabpanel"
      >
        {overrides[activeView] ?? (
          <DefaultView
            definition={definition}
            records={records}
            kind={activeView}
            selectedDate={selectedDate}
            onSelectDate={onSelectDate}
          />
        )}
        {supplements[activeView]}
      </div>
    </section>
  );
}
