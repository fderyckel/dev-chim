"use client";

import {
  useRef,
  useSyncExternalStore,
  type Dispatch,
  type SetStateAction,
} from "react";
import type { CalendarMode, CalendarViewContext } from "./model-view-contract";
import type { CalendarEntry } from "./calendar-data";
import {
  addMonths,
  formatLocalDate,
  monthDays,
  monthLabel,
  parseLocalDate,
  toIsoLocalDate,
} from "./local-date";

export type CalendarState = {
  month: string;
  date: string;
  status: string;
  selectedId: string | null;
  mode: CalendarMode | null;
};

type CalendarProps = {
  entries: ReadonlyArray<CalendarEntry>;
  state: CalendarState;
  setState: Dispatch<SetStateAction<CalendarState>>;
  context?: CalendarViewContext;
  onSelectDate?: (value: string) => void;
};

function subscribeNarrow(callback: () => void) {
  const query = window.matchMedia?.("(max-width: 44rem)");
  query?.addEventListener("change", callback);
  return () => query?.removeEventListener("change", callback);
}
function narrowSnapshot() {
  return window.matchMedia?.("(max-width: 44rem)").matches ?? false;
}
function serverSnapshot() {
  return false;
}

export function CalendarNavigation({
  entries,
  state,
  setState,
  context,
  onSelectDate,
  calendar = true,
}: CalendarProps & { calendar?: boolean }) {
  const narrow = useSyncExternalStore(subscribeNarrow, narrowSnapshot, serverSnapshot);
  const mode = state.mode ?? (narrow ? "agenda" : "month");
  const first =
    context?.coverageStart ??
    entries.reduce(
      (value, entry) => (!value || entry.from < value ? entry.from : value),
      "",
    );
  const last =
    context?.coverageEnd ??
    entries.reduce(
      (value, entry) => (entry.through > value ? entry.through : value),
      "",
    );
  const locale = context?.locale ?? "en-GB";
  const statuses = [...new Set(entries.map((entry) => entry.status).filter(Boolean))];
  function selectDate(date: string) {
    if (!date) {
      setState((old) => ({ ...old, date: "", selectedId: null }));
      return;
    }
    if (parseLocalDate(date) === null) return;
    setState((old) => ({ ...old, date, month: date.slice(0, 7), selectedId: null }));
    onSelectDate?.(date);
  }
  function move(delta: number) {
    const month = addMonths(state.month, delta);
    const day = `${month}-01` < first ? first : `${month}-01`;
    setState((old) => ({ ...old, month, date: day, selectedId: null }));
  }
  if (!state.month) return null;
  return (
    <div className="c-date-navigation">
      {context ? (
        <p className="c-date-context">
          {context.scopeLabel} · {context.timeZone}
        </p>
      ) : null}
      <div className="c-date-navigation__row">
        <button
          className="c-model-view-control"
          type="button"
          disabled={state.month <= first.slice(0, 7)}
          onClick={() => move(-1)}
        >
          Previous month
        </button>
        <h2 aria-live="polite" aria-atomic="true">
          {monthLabel(state.month, locale)}
        </h2>
        <button
          className="c-model-view-control"
          type="button"
          disabled={state.month >= last.slice(0, 7)}
          onClick={() => move(1)}
        >
          Next month
        </button>
      </div>
      <div className="c-date-navigation__tools">
        {calendar ? (
          <div className="c-date-modes" role="group" aria-label="Calendar display">
            {(["month", "agenda"] as const).map((value) => (
              <button
                className="c-model-view-control"
                type="button"
                key={value}
                aria-pressed={mode === value}
                onClick={() => setState((old) => ({ ...old, mode: value }))}
              >
                {value === "month" ? "Month" : "Agenda"}
              </button>
            ))}
          </div>
        ) : null}
        <label className="c-date-field">
          Jump to date
          <input
            type="date"
            value={state.date}
            min={first}
            max={last}
            onChange={(event) => selectDate(event.target.value)}
          />
        </label>
        {context ? (
          <button
            className="c-model-view-control"
            type="button"
            onClick={() => selectDate(context.referenceDate)}
          >
            {context.referenceLabel}
          </button>
        ) : null}
        {statuses.length > 1 ? (
          <label className="c-date-field">
            Show
            <select
              value={state.status}
              onChange={(event) =>
                setState((old) => ({
                  ...old,
                  status: event.target.value,
                  selectedId: null,
                }))
              }
            >
              <option value="">All types</option>
              {statuses.map((status) => (
                <option key={status}>{status}</option>
              ))}
            </select>
          </label>
        ) : null}
      </div>
      <p className="c-date-context">
        {first && last
          ? `Loaded dates: ${formatLocalDate(first, locale)} – ${formatLocalDate(last, locale)}`
          : "No dated records are supplied."}
        {context
          ? ` · ${context.referenceLabel}: ${formatLocalDate(context.referenceDate, locale)}`
          : ""}
      </p>
    </div>
  );
}

function DateRange({ entry, locale }: { entry: CalendarEntry; locale: string }) {
  return (
    <span>
      {formatLocalDate(entry.from, locale)}
      {entry.through === entry.from
        ? ""
        : ` – ${formatLocalDate(entry.through, locale)}`}
    </span>
  );
}

function CalendarEntryList({
  items,
  label,
  locale,
  month,
  onOpen,
}: {
  items: ReadonlyArray<CalendarEntry>;
  label: string;
  locale: string;
  month: string;
  onOpen: (entry: CalendarEntry, button: HTMLButtonElement) => void;
}) {
  return (
    <ul className="c-date-entries" aria-label={label}>
      {items.map((entry) => (
        <li key={entry.id}>
          <button
            type="button"
            className="c-date-entry"
            data-context={entry.context ? "true" : "false"}
            aria-label={`${entry.status ? `${entry.status} ` : ""}${entry.title}, ${formatLocalDate(entry.from, locale)}${entry.through === entry.from ? "" : ` to ${formatLocalDate(entry.through, locale)}`}${entry.scope ? `, ${entry.scope}` : ""}`}
            onClick={(event) => onOpen(entry, event.currentTarget)}
          >
            <span className="c-date-entry__type">{entry.status}</span>
            <strong>{entry.title}</strong>
            <DateRange entry={entry} locale={locale} />
            {entry.scope ? <span>{entry.scope}</span> : null}
            {entry.context && entry.from.slice(0, 7) < month ? (
              <span>Continues from {formatLocalDate(entry.from, locale)}</span>
            ) : null}
          </button>
        </li>
      ))}
    </ul>
  );
}

export function ModelCalendarView({
  entries,
  state,
  setState,
  context,
  onSelectDate,
}: CalendarProps) {
  const narrow = useSyncExternalStore(subscribeNarrow, narrowSnapshot, serverSnapshot);
  const mode = state.mode ?? (narrow ? "agenda" : "month");
  const dayHeading = useRef<HTMLHeadingElement>(null);
  const calendarRegion = useRef<HTMLElement>(null);
  const detailsHeading = useRef<HTMLHeadingElement>(null);
  const returnButton = useRef<HTMLButtonElement | null>(null);
  const locale = context?.locale ?? "en-GB";
  const weekStartsOn = context?.weekStartsOn ?? 1;
  const cells = monthDays(state.month, weekStartsOn);
  const days = cells.filter((day): day is number => day !== null);
  const selectedDay = parseLocalDate(state.date);
  const selected = entries.find((entry) => entry.id === state.selectedId);
  const dayEntries = entries.filter(
    (entry) =>
      selectedDay !== null && entry.start <= selectedDay && entry.end >= selectedDay,
  );
  const contextEntries = entries.filter((entry) => entry.context);
  const dated = entries.filter((entry) => !entry.context);
  const outside =
    !!context &&
    (state.date < context.coverageStart || state.date > context.coverageEnd);
  const weekdayNames = Array.from({ length: 7 }, (_, index) =>
    new Intl.DateTimeFormat(locale, { weekday: "short", timeZone: "UTC" }).format(
      new Date(Date.UTC(2026, 10, 1 + ((index + weekStartsOn) % 7))),
    ),
  );

  function selectDay(value: string, focus = false) {
    setState((old) => ({ ...old, date: value, selectedId: null }));
    onSelectDate?.(value);
    if (focus) requestAnimationFrame(() => dayHeading.current?.focus());
  }
  function handleOpen(entry: CalendarEntry, button: HTMLButtonElement) {
    returnButton.current = button;
    setState((old) => ({ ...old, selectedId: entry.id }));
    requestAnimationFrame(() => detailsHeading.current?.focus());
  }
  return (
    <section
      className="c-date-view"
      aria-label="Calendar entries"
      ref={calendarRegion}
      tabIndex={-1}
    >
      {contextEntries.length ? (
        <section className="c-date-periods" aria-label="Ongoing date ranges">
          <CalendarEntryList
            items={contextEntries}
            label="Date range context"
            locale={locale}
            month={state.month}
            onOpen={handleOpen}
          />
        </section>
      ) : null}
      <div role="status" className="c-date-context">
        {outside
          ? "Outside the supplied date coverage."
          : entries.length
            ? `${entries.length} ${entries.length === 1 ? "entry" : "entries"} in this view.`
            : state.status
              ? "No matching entries in this month."
              : "No entries in the supplied month."}
      </div>
      {!entries.length && state.status ? (
        <button
          className="c-model-view-control"
          type="button"
          onClick={() => setState((old) => ({ ...old, status: "", selectedId: null }))}
        >
          Clear filters
        </button>
      ) : null}
      {mode === "month" && days.length ? (
        <div
          className="c-date-month"
          aria-label={`${monthLabel(state.month, locale)} month view`}
        >
          <div className="c-date-weekdays">
            {weekdayNames.map((name, index) => (
              <span key={index}>{name}</span>
            ))}
          </div>
          <div className="c-date-grid">
            {cells.map((day, index) => {
              if (day === null)
                return (
                  <div
                    className="c-date-cell c-date-cell--blank"
                    key={`blank-${index}`}
                  />
                );
              const value = toIsoLocalDate(day);
              const items = dated.filter(
                (entry) => entry.start <= day && entry.end >= day,
              );
              const ranges = contextEntries.filter(
                (entry) => entry.start <= day && entry.end >= day,
              );
              const disabled =
                !!context &&
                (value < context.coverageStart || value > context.coverageEnd);
              const all = [...ranges, ...items];
              return (
                <div
                  className="c-date-cell"
                  key={value}
                  data-selected={value === state.date ? "true" : "false"}
                  data-context={ranges.length ? "true" : "false"}
                >
                  <button
                    className="c-date-day"
                    type="button"
                    disabled={disabled}
                    aria-pressed={value === state.date}
                    aria-label={`${formatLocalDate(value, locale)}${
                      all.length
                        ? `, ${all
                            .slice(0, 2)
                            .map((entry) => entry.title)
                            .join(
                              ", ",
                            )}${all.length > 2 ? `, ${all.length - 2} more entries` : ""}`
                        : ""
                    }`}
                    onClick={() => selectDay(value)}
                  >
                    {Number(value.slice(-2))}
                  </button>
                  {ranges.length ? (
                    <span className="c-date-cell__range" aria-hidden="true">
                      {ranges.map((entry) => entry.title).join(" · ")}
                    </span>
                  ) : null}
                  {items.length ? (
                    <span className="c-date-cell__summary" aria-hidden="true">
                      {items.length} {items.length === 1 ? "item" : "items"}
                    </span>
                  ) : null}
                  {items.slice(0, 2).map((entry) => (
                    <span className="c-date-cell__entry" key={entry.id}>
                      <strong>{entry.title}</strong>
                      <span>{entry.status}</span>
                    </span>
                  ))}
                  {items.length > 2 ? (
                    <button
                      type="button"
                      className="c-date-more"
                      aria-label={`${items.length - 2} more entries on ${formatLocalDate(value, locale)}`}
                      onClick={() => selectDay(value, true)}
                    >
                      +{items.length - 2} more
                    </button>
                  ) : null}
                </div>
              );
            })}
          </div>
        </div>
      ) : null}
      {mode === "agenda" ? (
        <section
          className="c-date-agenda"
          aria-label={`${monthLabel(state.month, locale)} agenda`}
        >
          {days.map((day) => {
            const items = dated.filter(
              (entry) => entry.start <= day && entry.end >= day,
            );
            if (!items.length) return null;
            const value = toIsoLocalDate(day);
            return (
              <section key={day}>
                <h3>{formatLocalDate(value, locale)}</h3>
                <CalendarEntryList
                  items={items}
                  label={`Entries on ${formatLocalDate(value, locale)}`}
                  locale={locale}
                  month={state.month}
                  onOpen={handleOpen}
                />
              </section>
            );
          })}
          {!dated.length ? (
            <p>No dated events in this month. Date ranges appear above.</p>
          ) : null}
        </section>
      ) : null}
      {mode === "month" ? (
        <section className="c-date-day-agenda" aria-label="Selected day">
          <h3 ref={dayHeading} tabIndex={-1}>
            {state.date ? formatLocalDate(state.date, locale) : "Select a date"}
          </h3>
          {outside ? (
            <p>This date is outside the supplied coverage.</p>
          ) : dayEntries.length ? (
            <CalendarEntryList
              items={dayEntries}
              label="Selected day entries"
              locale={locale}
              month={state.month}
              onOpen={handleOpen}
            />
          ) : (
            <p>No items on this date in the current view.</p>
          )}
        </section>
      ) : null}
      {selected ? (
        <section className="c-date-details" aria-label="Entry details">
          <h3 tabIndex={-1} ref={detailsHeading}>
            {selected.title}
          </h3>
          <dl>
            <div>
              <dt>Type</dt>
              <dd>{selected.status || "Dated record"}</dd>
            </div>
            <div>
              <dt>Dates · inclusive</dt>
              <dd>
                <DateRange entry={selected} locale={locale} />
              </dd>
            </div>
            {selected.scope ? (
              <div>
                <dt>Scope</dt>
                <dd>{selected.scope}</dd>
              </div>
            ) : null}
            {context ? (
              <div>
                <dt>Calendar</dt>
                <dd>
                  {context.scopeLabel} · {context.timeZone}
                </dd>
              </div>
            ) : null}
          </dl>
          <button
            type="button"
            className="c-model-view-control"
            onClick={() => {
              setState((old) => ({ ...old, selectedId: null }));
              if (returnButton.current?.isConnected) returnButton.current.focus();
              else (dayHeading.current ?? calendarRegion.current)?.focus();
            }}
          >
            Close details
          </button>
        </section>
      ) : null}
    </section>
  );
}
