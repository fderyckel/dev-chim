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
  type CalendarViewContext,
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
  monthLabel,
  parseLocalDate,
  toIsoLocalDate,
} from "./local-date";

import {
  calendarEntries,
  calendarContextIssues,
  entriesInMonth,
} from "./calendar-data";
import {
  CalendarNavigation,
  ModelCalendarView,
  type CalendarState,
} from "./model-calendar-view";

type WorkspaceProps = Readonly<{
  definition: ModelViewSetDefinition;
  records: ReadonlyArray<ModelViewRecord>;
  overrides?: Partial<Record<ModelViewKind, ReactNode>>;
  supplements?: Partial<Record<ModelViewKind, ReactNode>>;
  selectedDate?: string;
  onSelectDate?: (value: string) => void;
  calendarContext?: CalendarViewContext;
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
}: Readonly<{
  definition: ModelViewSetDefinition;
  records: ReadonlyArray<ModelViewRecord>;
  kind: ModelViewKind;
}>) {
  const view = viewDefinition(definition, kind);
  if (!view) return <p className="c-model-view-empty">This view is unavailable.</p>;

  switch (view.kind) {
    case "list":
      return <ModelListView definition={definition} records={records} view={view} />;
    case "form":
      return <ModelFormView definition={definition} records={records} view={view} />;
    case "calendar":
      return null;
    case "gantt":
      return <ModelGanttView definition={definition} records={records} view={view} />;
  }
}

function ValidatedWorkspace({
  definition,
  records,
  overrides = {},
  supplements = {},
  selectedDate,
  onSelectDate,
  calendarContext,
}: WorkspaceProps) {
  const [activeView, setActiveView] = useState<ModelViewKind>(definition.defaultView);
  const datedView = definition.views.find(
    (view): view is CalendarViewDefinition => view.kind === "calendar",
  );
  const parsed = useMemo(
    () =>
      datedView
        ? calendarEntries(definition, records, datedView)
        : { entries: [], issues: [] },
    [definition, records, datedView],
  );
  const allEntries = parsed.entries;
  const issues = [
    ...parsed.issues,
    ...calendarContextIssues(calendarContext),
    ...(selectedDate && parseLocalDate(selectedDate) === null
      ? ["The selected calendar date is invalid."]
      : []),
  ];
  const initialDate =
    selectedDate ?? calendarContext?.referenceDate ?? allEntries[0]?.from ?? "";
  const [calendarState, setCalendarState] = useState<CalendarState>({
    date: initialDate,
    month: initialDate.slice(0, 7),
    status: "",
    selectedId: null,
    mode: null,
  });
  const [previousSelectedDate, setPreviousSelectedDate] = useState(selectedDate);
  // A controlled workflow can resolve another date; ordinary view switches keep local context.
  if (previousSelectedDate !== selectedDate) {
    setPreviousSelectedDate(selectedDate);
    if (selectedDate && parseLocalDate(selectedDate) !== null) {
      setCalendarState((old) => ({
        ...old,
        date: selectedDate,
        month: selectedDate.slice(0, 7),
        selectedId: null,
      }));
    }
  }
  const visibleEntries = entriesInMonth(
    allEntries,
    calendarState.month,
    calendarState.status,
  );
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
        {!issues.length &&
        datedView &&
        (activeView === "calendar" || activeView === "list") ? (
          <CalendarNavigation
            entries={allEntries}
            state={calendarState}
            setState={setCalendarState}
            context={calendarContext}
            onSelectDate={onSelectDate}
            calendar={activeView === "calendar"}
          />
        ) : null}
        {!issues.length &&
        datedView &&
        activeView === "list" &&
        !visibleEntries.length ? (
          <div className="c-date-navigation">
            <p role="status">
              {calendarState.status
                ? "No matching entries in this month."
                : "No entries in the supplied month."}
            </p>
            {calendarState.status ? (
              <button
                className="c-model-view-control"
                type="button"
                onClick={() =>
                  setCalendarState((old) => ({ ...old, status: "", selectedId: null }))
                }
              >
                Clear filters
              </button>
            ) : null}
          </div>
        ) : null}
        {issues.length && (activeView === "calendar" || activeView === "list") ? (
          <div className="c-model-view-error" role="alert">
            <strong>Calendar data unavailable.</strong>
            <p>{issues[0]}</p>
            <button
              className="c-model-view-control"
              type="button"
              onClick={() => window.location.reload()}
            >
              Reload view
            </button>
          </div>
        ) : (
          (overrides[activeView] ??
          (activeView === "calendar" ? (
            <ModelCalendarView
              entries={visibleEntries}
              state={calendarState}
              setState={setCalendarState}
              context={calendarContext}
              onSelectDate={onSelectDate}
            />
          ) : (
            <DefaultView
              definition={definition}
              records={
                activeView === "list" && datedView
                  ? visibleEntries.map((entry) => entry.record)
                  : records
              }
              kind={activeView}
            />
          )))
        )}
        {supplements[activeView]}
      </div>
    </section>
  );
}

export function ModelViewWorkspace(props: WorkspaceProps) {
  const issues = validateModelViewSet(props.definition);
  if (issues.length)
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
  return (
    <ValidatedWorkspace
      key={`${props.definition.sourceRef}:${props.calendarContext?.sourceKey ?? ""}`}
      {...props}
    />
  );
}
