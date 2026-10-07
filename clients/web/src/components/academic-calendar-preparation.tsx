"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import createClient from "openapi-fetch";

import { ActionButton } from "../design-system/components/actions";
import { PageHeading } from "../design-system/components/page-heading";
import { Panel } from "../design-system/components/panel";
import { StatusBadge } from "../design-system/components/status-badge";
import {
  prepareCalendarPreview,
  resolveCalendarDate,
  type CalendarPreview,
} from "../lib/academic-calendar-preview";
import type {
  AcademicCalendarDraft,
  AcademicCalendarPreparationViewData,
} from "../ports/view-data";
import type { components, paths } from "../generated/public/session-schema";

type AcademicCalendarPreparationProps = Readonly<{
  connected?: boolean;
  viewData: AcademicCalendarPreparationViewData;
}>;

type Mutable<T> = T extends readonly (infer U)[]
  ? Mutable<U>[]
  : T extends object
    ? { -readonly [K in keyof T]: Mutable<T[K]> }
    : T;
type WriterView = components["schemas"]["CalendarPreparationView"];
type WriterResolution = components["schemas"]["CalendarResolution"];
type SaveInput = Mutable<components["schemas"]["SaveCalendarDraftRequest"]>;
type PublishInput = Mutable<components["schemas"]["PublishAcademicYearRequest"]>;

const client = createClient<Mutable<paths>>({
  credentials: "same-origin",
  cache: "no-store",
});

const weekdays = [
  { value: 1, short: "Mon", label: "Monday" },
  { value: 2, short: "Tue", label: "Tuesday" },
  { value: 3, short: "Wed", label: "Wednesday" },
  { value: 4, short: "Thu", label: "Thursday" },
  { value: 5, short: "Fri", label: "Friday" },
  { value: 6, short: "Sat", label: "Saturday" },
  { value: 7, short: "Sun", label: "Sunday" },
] as const;

const dateFormatter = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  year: "numeric",
  timeZone: "UTC",
});

function formatDate(value: string): string {
  return dateFormatter.format(new Date(`${value}T00:00:00Z`));
}

function initialPreview(definition: AcademicCalendarDraft): CalendarPreview {
  const result = prepareCalendarPreview(definition);
  if (!result.ok) throw new Error("The synthetic calendar fixture is invalid.");
  return result.preview;
}

function draftFromWriter(view: WriterView): AcademicCalendarDraft {
  return {
    label: view.definition.label,
    code: view.definition.code,
    startOn: view.definition.start_on,
    endOn: view.definition.end_on,
    timeZone: view.definition.time_zone,
    instructionalWeekdays: [...view.definition.instructional_weekdays],
    periods: view.definition.periods.map((period) => ({
      id: period.id,
      label: period.label,
      periodTypeKey: period.period_type_key,
      sequence: period.sequence,
      startOn: period.start_on,
      endOn: period.end_on,
    })),
    closures: view.definition.closures.map((closure) => ({
      id: closure.id,
      label: closure.label,
      date: closure.date,
      reasonKey: closure.reason_key,
    })),
  };
}

function previewFromWriter(view: WriterView): CalendarPreview {
  const result = prepareCalendarPreview(draftFromWriter(view));
  if (!result.ok) throw new Error("The authoritative calendar response is invalid.");
  return { ...result.preview, instructionalDateCount: view.instructional_date_count };
}

const reasonLabels = {
  closure: "Named closure",
  instructional_weekday: "Instructional weekday",
  ordinary_weekday_off: "Ordinary weekday off",
  outside_period: "Outside all terms",
  outside_year: "Outside this academic year",
} as const;

export function AcademicCalendarPreparation({
  connected = false,
  viewData,
}: AcademicCalendarPreparationProps) {
  const [draft, setDraft] = useState(viewData.calendar);
  const [preview, setPreview] = useState(() => initialPreview(viewData.calendar));
  const [resolutionDate, setResolutionDate] = useState(viewData.initialResolutionDate);
  const [errors, setErrors] = useState<ReadonlyArray<string>>([]);
  const [dirty, setDirty] = useState(false);
  const [announcement, setAnnouncement] = useState(
    "Example calendar preview is ready.",
  );
  const [csrf, setCsrf] = useState<string | null>(null);
  const [writerView, setWriterView] = useState<WriterView | null>(null);
  const [writerResolution, setWriterResolution] = useState<WriterResolution | null>(
    null,
  );
  const [busy, setBusy] = useState(connected);
  const [mustReload, setMustReload] = useState(false);
  const saveAttempt = useRef<SaveInput | null>(null);
  const publishAttempt = useRef<PublishInput | null>(null);

  const localResolution = resolveCalendarDate(preview, resolutionDate);
  const resolution = writerResolution
    ? {
        status: writerResolution.status,
        reason: writerResolution.reason,
        periodLabel: preview.periods.find(
          (period) => period.id === writerResolution.academic_period_id,
        )?.label,
        closureLabel: preview.closures.find(
          (closure) => closure.id === writerResolution.closure_id,
        )?.label,
      }
    : localResolution;
  const editorDisabled =
    connected && (busy || mustReload || writerView?.status === "published");
  const awaitingWriterResolution =
    connected && writerView?.status === "published" && !writerResolution;

  function applyWriterView(view: WriterView, message: string) {
    const nextDraft = draftFromWriter(view);
    setWriterView(view);
    setDraft(nextDraft);
    setPreview(previewFromWriter(view));
    setErrors([]);
    setDirty(false);
    setMustReload(false);
    setWriterResolution(null);
    saveAttempt.current = null;
    publishAttempt.current = null;
    setAnnouncement(message);
  }

  function clearSession(message: string) {
    setCsrf(null);
    setWriterView(null);
    setWriterResolution(null);
    setMustReload(false);
    setAnnouncement(message);
  }

  function connectedFailure(status: number, code?: string) {
    if (status === 401 || status === 403) {
      clearSession("Your calendar access is no longer current. Sign in again.");
      return;
    }
    if (status === 400) {
      setErrors([
        code === "unsupported_time_zone"
          ? "Use a supported IANA time zone."
          : "The writer rejected this calendar definition. Review every field.",
      ]);
      setAnnouncement("The draft was not saved. Review the highlighted issue.");
      return;
    }
    setMustReload(true);
    setAnnouncement(
      status === 409
        ? "This calendar changed or is no longer editable. Reload it before continuing."
        : "We could not confirm the result. Reload the calendar to check what was saved.",
    );
  }

  async function loadWriterCalendar(token = csrf) {
    if (!token) return;
    const result = await client.GET("/api/v1/calendar/preparation");
    if (!result.data) {
      connectedFailure(result.response.status, result.error?.errors[0]?.code);
      return;
    }
    applyWriterView(
      result.data.data,
      result.data.data.status === "published"
        ? "Published calendar loaded from the school database."
        : "Saved draft loaded from the school database.",
    );
  }

  async function session() {
    const result = await client.GET("/api/v1/session");
    if (!result.data) {
      clearSession("Start a synthetic calendar-owner session to open the saved draft.");
      return;
    }
    const token = result.data.data.csrf_token;
    setCsrf(token);
    await loadWriterCalendar(token);
  }

  useEffect(() => {
    if (!connected) return;
    void Promise.resolve()
      .then(session)
      .catch(() =>
        clearSession("The local calendar service is unavailable. Try again."),
      )
      .finally(() => setBusy(false));
    // Connected mode checks the current writer-backed session only on arrival.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [connected]);

  async function guarded(action: () => Promise<void>) {
    setBusy(true);
    try {
      await action();
    } catch {
      setMustReload(true);
      setAnnouncement(
        "Connection interrupted. Reload the calendar to check what was saved.",
      );
    } finally {
      setBusy(false);
    }
  }

  function changeDraft(next: AcademicCalendarDraft) {
    setDraft(next);
    setDirty(true);
    setErrors([]);
    setWriterResolution(null);
    saveAttempt.current = null;
    setAnnouncement("Changes are waiting for preview.");
  }

  function updatePeriod(
    id: string,
    field: "label" | "startOn" | "endOn",
    value: string,
  ) {
    changeDraft({
      ...draft,
      periods: draft.periods.map((period) =>
        period.id === id ? { ...period, [field]: value } : period,
      ),
    });
  }

  function updateClosure(id: string, field: "label" | "date", value: string) {
    changeDraft({
      ...draft,
      closures: draft.closures.map((closure) =>
        closure.id === id ? { ...closure, [field]: value } : closure,
      ),
    });
  }

  function toggleWeekday(day: number) {
    const selected = draft.instructionalWeekdays.includes(day);
    changeDraft({
      ...draft,
      instructionalWeekdays: selected
        ? draft.instructionalWeekdays.filter((value) => value !== day)
        : [...draft.instructionalWeekdays, day].sort(),
    });
  }

  function previewCalendar(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const result = prepareCalendarPreview(draft);

    if (!result.ok) {
      setErrors(result.errors);
      setAnnouncement(
        `Preview unavailable. ${result.errors.length} ${result.errors.length === 1 ? "issue needs" : "issues need"} attention.`,
      );
      return;
    }

    if (connected) {
      if (!csrf || !writerView || writerView.status !== "draft") return;
      void guarded(async () => {
        const body: SaveInput = saveAttempt.current ?? {
          label: draft.label,
          code: draft.code,
          start_on: draft.startOn,
          end_on: draft.endOn,
          time_zone: draft.timeZone,
          instructional_weekdays: [...draft.instructionalWeekdays],
          periods: draft.periods.map((period) => ({
            id: period.id,
            label: period.label,
            period_type_key: period.periodTypeKey ?? "term",
            sequence: period.sequence,
            start_on: period.startOn,
            end_on: period.endOn,
          })),
          closures: draft.closures.map((closure) => ({
            id: closure.id,
            label: closure.label,
            date: closure.date,
            reason_key: closure.reasonKey,
          })),
          expected_version: writerView.lock_version,
          idempotency_key: crypto.randomUUID(),
          causation_id: crypto.randomUUID(),
        };
        saveAttempt.current = body;
        const response = await client.POST("/api/v1/calendar/save-draft", {
          body,
          params: {
            header: { Origin: window.location.origin, "X-CSRF-Token": csrf },
          },
        });
        if (!response.data) {
          connectedFailure(response.response.status, response.error?.errors[0]?.code);
          return;
        }
        applyWriterView(
          response.data.data,
          `Draft saved and read back with ${response.data.data.instructional_date_count} instructional dates.`,
        );
      });
      return;
    }

    setPreview(result.preview);
    setErrors([]);
    setDirty(false);
    setAnnouncement(
      `Preview updated with ${result.preview.instructionalDateCount} instructional dates. Nothing was saved.`,
    );
  }

  function resetExample() {
    if (connected) {
      void guarded(() => loadWriterCalendar());
      return;
    }
    setDraft(viewData.calendar);
    setPreview(initialPreview(viewData.calendar));
    setResolutionDate(viewData.initialResolutionDate);
    setErrors([]);
    setDirty(false);
    setAnnouncement("Synthetic example restored. Nothing was saved.");
  }

  async function publishCalendar() {
    if (!csrf || !writerView || writerView.status !== "draft") return;
    const body: PublishInput = publishAttempt.current ?? {
      expected_version: writerView.lock_version,
      idempotency_key: crypto.randomUUID(),
      causation_id: crypto.randomUUID(),
    };
    publishAttempt.current = body;
    const response = await client.POST("/api/v1/calendar/publish", {
      body,
      params: {
        header: { Origin: window.location.origin, "X-CSRF-Token": csrf },
      },
    });
    if (!response.data) {
      connectedFailure(response.response.status, response.error?.errors[0]?.code);
      return;
    }
    applyWriterView(
      response.data.data,
      "Academic year published and read back from the school database.",
    );
  }

  async function resolveWriterDate() {
    if (!csrf || writerView?.status !== "published") return;
    const response = await client.POST("/api/v1/calendar/resolve", {
      body: { local_date: resolutionDate },
      params: {
        header: { Origin: window.location.origin, "X-CSRF-Token": csrf },
      },
    });
    if (!response.data) {
      connectedFailure(response.response.status, response.error?.errors[0]?.code);
      return;
    }
    setWriterResolution(response.data.data);
    setAnnouncement("Date resolved from the published calendar in the database.");
  }

  return (
    <div className="l-page-stack">
      <PageHeading
        eyebrow={
          connected
            ? "CF-3 · connected calendar qualification"
            : "CF-2 · local preparation prototype"
        }
        title="Prepare an academic calendar"
        description={
          connected
            ? "Edit one server-selected synthetic academic year, save an authoritative draft, publish it, and resolve a date against the published calendar."
            : "Adjust a synthetic academic year, its terms, instructional weekdays, and closures. Preview the resulting dates before any connected writer exists."
        }
        aside={
          <>
            <StatusBadge
              tone={
                writerView?.status === "published"
                  ? "positive"
                  : writerView
                    ? "information"
                    : "attention"
              }
            >
              {connected
                ? writerView?.status === "published"
                  ? "Published"
                  : writerView
                    ? "Draft saved"
                    : "Sign in required"
                : "Not saved"}
            </StatusBadge>
            <span className="c-page-heading__assurance-copy">
              {connected
                ? "Local synthetic session · authoritative core writer"
                : "Local browser calculation · no core connection"}
            </span>
          </>
        }
      />

      <aside className="c-calendar-boundary" aria-label="Calendar preview boundary">
        <span className="c-calendar-boundary__mark" aria-hidden="true">
          i
        </span>
        <div>
          <strong>Safe to test</strong>
          <p>
            {connected
              ? "This isolated workflow contains fictional data. Saving and publishing change only its fresh local test database; no real institution, identity provider, timetable, event, or production service is connected."
              : "You can change every visible field and preview the result. This screen does not create an institution, save a draft, publish a year, or send data to the production core."}
          </p>
        </div>
      </aside>

      {connected ? (
        <p className="c-calendar-status" role="status" aria-live="polite">
          {announcement}
        </p>
      ) : null}

      {connected && !csrf ? (
        <Panel
          eyebrow="Synthetic access"
          title="Open the prepared calendar"
          titleId="calendar-sign-in-title"
          description="Start a local synthetic calendar-owner session. No real account or identity provider is used."
        >
          <ActionButton
            disabled={busy}
            onClick={() =>
              void guarded(async () => {
                const result = await fetch("/api/v1/classroom-demo/sign-in", {
                  method: "POST",
                  headers: { "Content-Type": "application/json" },
                  body: "{}",
                  cache: "no-store",
                });
                if (!result.ok) throw new Error("Sign-in unavailable");
                await session();
              })
            }
          >
            {busy ? "Checking session…" : "Start synthetic calendar-owner session"}
          </ActionButton>
        </Panel>
      ) : (
        <div className="l-calendar-workspace">
          <form className="c-calendar-form" onSubmit={previewCalendar}>
            <header className="c-calendar-form__header">
              <div>
                <p className="c-panel__eyebrow">
                  {connected ? "Writer-backed definition" : "Synthetic definition"}
                </p>
                <h2>Calendar details</h2>
                <p className="c-calendar-form__institution">
                  {viewData.institution.label}
                </p>
              </div>
              <StatusBadge tone={dirty ? "attention" : "positive"}>
                {dirty
                  ? connected
                    ? "Changes not saved"
                    : "Changes not previewed"
                  : connected
                    ? writerView?.status === "published"
                      ? "Published"
                      : "Saved draft current"
                    : "Preview current"}
              </StatusBadge>
            </header>

            <div className="c-calendar-form__body">
              <div className="l-calendar-fields">
                <label className="c-field" htmlFor="calendar-label">
                  <span className="c-field__label">Academic year label</span>
                  <input
                    className="c-input"
                    id="calendar-label"
                    disabled={editorDisabled}
                    value={draft.label}
                    onChange={(event) =>
                      changeDraft({ ...draft, label: event.target.value })
                    }
                  />
                </label>
                <label className="c-field" htmlFor="calendar-code">
                  <span className="c-field__label">Code</span>
                  <input
                    className="c-input"
                    id="calendar-code"
                    disabled={editorDisabled}
                    value={draft.code}
                    onChange={(event) =>
                      changeDraft({ ...draft, code: event.target.value })
                    }
                  />
                </label>
              </div>

              <div className="l-calendar-date-pair">
                <label className="c-field" htmlFor="calendar-start">
                  <span className="c-field__label">Year starts</span>
                  <input
                    className="c-input"
                    id="calendar-start"
                    disabled={editorDisabled}
                    type="date"
                    value={draft.startOn}
                    onChange={(event) =>
                      changeDraft({ ...draft, startOn: event.target.value })
                    }
                  />
                </label>
                <label className="c-field" htmlFor="calendar-end">
                  <span className="c-field__label">Year ends</span>
                  <input
                    className="c-input"
                    id="calendar-end"
                    disabled={editorDisabled}
                    type="date"
                    value={draft.endOn}
                    onChange={(event) =>
                      changeDraft({ ...draft, endOn: event.target.value })
                    }
                  />
                </label>
              </div>

              <label className="c-field" htmlFor="calendar-time-zone">
                <span className="c-field__label">Calendar time zone</span>
                <input
                  className="c-input"
                  id="calendar-time-zone"
                  disabled={editorDisabled}
                  value={draft.timeZone}
                  onChange={(event) =>
                    changeDraft({ ...draft, timeZone: event.target.value })
                  }
                />
                <span className="c-field__hint">
                  This calendar keeps its own explicit IANA time zone.
                </span>
              </label>

              <fieldset className="c-weekday-fieldset">
                <legend>Instructional weekdays</legend>
                <div className="c-weekday-options">
                  {weekdays.map((weekday) => (
                    <label className="c-weekday-option" key={weekday.value}>
                      <input
                        className="c-weekday-option__control"
                        checked={draft.instructionalWeekdays.includes(weekday.value)}
                        disabled={editorDisabled}
                        onChange={() => toggleWeekday(weekday.value)}
                        type="checkbox"
                      />
                      <span className="c-weekday-option__short" aria-hidden="true">
                        {weekday.short}
                      </span>
                      <span className="u-visually-hidden">{weekday.label}</span>
                    </label>
                  ))}
                </div>
              </fieldset>

              <fieldset className="c-calendar-collection">
                <legend>Terms</legend>
                <div className="c-calendar-collection__items">
                  {draft.periods.map((period) => (
                    <div className="c-calendar-entry" key={period.id}>
                      <label className="c-field" htmlFor={`term-${period.id}-label`}>
                        <span className="c-field__label">Term {period.sequence}</span>
                        <input
                          className="c-input"
                          id={`term-${period.id}-label`}
                          disabled={editorDisabled}
                          value={period.label}
                          onChange={(event) =>
                            updatePeriod(period.id, "label", event.target.value)
                          }
                        />
                      </label>
                      <div className="l-calendar-date-pair">
                        <label className="c-field" htmlFor={`term-${period.id}-start`}>
                          <span className="c-field__label">Starts</span>
                          <input
                            aria-label={`${period.label} Starts`}
                            className="c-input"
                            id={`term-${period.id}-start`}
                            disabled={editorDisabled}
                            type="date"
                            value={period.startOn}
                            onChange={(event) =>
                              updatePeriod(period.id, "startOn", event.target.value)
                            }
                          />
                        </label>
                        <label className="c-field" htmlFor={`term-${period.id}-end`}>
                          <span className="c-field__label">Ends</span>
                          <input
                            aria-label={`${period.label} Ends`}
                            className="c-input"
                            id={`term-${period.id}-end`}
                            disabled={editorDisabled}
                            type="date"
                            value={period.endOn}
                            onChange={(event) =>
                              updatePeriod(period.id, "endOn", event.target.value)
                            }
                          />
                        </label>
                      </div>
                    </div>
                  ))}
                </div>
              </fieldset>

              <fieldset className="c-calendar-collection">
                <legend>Closures</legend>
                <div className="c-calendar-collection__items">
                  {draft.closures.map((closure) => (
                    <div
                      className="c-calendar-entry c-calendar-entry--closure"
                      key={closure.id}
                    >
                      <label
                        className="c-field"
                        htmlFor={`closure-${closure.id}-label`}
                      >
                        <span className="c-field__label">Closure label</span>
                        <input
                          className="c-input"
                          id={`closure-${closure.id}-label`}
                          disabled={editorDisabled}
                          value={closure.label}
                          onChange={(event) =>
                            updateClosure(closure.id, "label", event.target.value)
                          }
                        />
                      </label>
                      <label className="c-field" htmlFor={`closure-${closure.id}-date`}>
                        <span className="c-field__label">Date</span>
                        <input
                          className="c-input"
                          id={`closure-${closure.id}-date`}
                          disabled={editorDisabled}
                          type="date"
                          value={closure.date}
                          onChange={(event) =>
                            updateClosure(closure.id, "date", event.target.value)
                          }
                        />
                      </label>
                    </div>
                  ))}
                </div>
              </fieldset>

              {errors.length > 0 ? (
                <div className="c-calendar-errors" role="alert">
                  <strong>Preview needs attention</strong>
                  <ul>
                    {errors.map((error) => (
                      <li key={error}>{error}</li>
                    ))}
                  </ul>
                </div>
              ) : null}
            </div>

            <footer className="c-calendar-form__actions">
              <ActionButton
                disabled={editorDisabled || (connected && !dirty)}
                type="submit"
                variant="primary"
              >
                {connected ? (busy ? "Saving…" : "Save draft") : "Preview calendar"}
              </ActionButton>
              <ActionButton disabled={busy} onClick={resetExample} variant="secondary">
                {connected ? "Reload from database" : "Reset example"}
              </ActionButton>
              {connected && writerView?.status === "draft" ? (
                <ActionButton
                  disabled={busy || dirty || mustReload}
                  onClick={() => void guarded(publishCalendar)}
                  variant="secondary"
                >
                  Publish academic year
                </ActionButton>
              ) : null}
              <p className="c-calendar-form__note">
                {connected
                  ? writerView?.status === "published"
                    ? "Published definitions are immutable in this slice."
                    : "Publishing is irreversible in this local qualification slice."
                  : "No save or publish action exists in this prototype."}
              </p>
            </footer>
          </form>

          <div className="c-calendar-preview" aria-label="Prepared calendar preview">
            <Panel
              eyebrow="Prepared result"
              title={preview.definition.label}
              titleId="calendar-preview-title"
              badge={
                <StatusBadge
                  tone={writerView?.status === "published" ? "positive" : "information"}
                >
                  {connected
                    ? writerView?.status === "published"
                      ? "Published"
                      : "Authoritative draft"
                    : "Local preview"}
                </StatusBadge>
              }
              footer={
                connected
                  ? `Time zone: ${preview.definition.timeZone} · Read from the core writer.`
                  : `Time zone: ${preview.definition.timeZone} · This result is not persisted.`
              }
            >
              <div className="c-calendar-metrics">
                <div>
                  <strong className="c-calendar-metrics__value">
                    {preview.instructionalDateCount}
                  </strong>
                  <span className="c-calendar-metrics__label">Instructional dates</span>
                </div>
                <div>
                  <strong className="c-calendar-metrics__value">
                    {preview.periods.length}
                  </strong>
                  <span className="c-calendar-metrics__label">Terms</span>
                </div>
                <div>
                  <strong className="c-calendar-metrics__value">
                    {preview.closures.length}
                  </strong>
                  <span className="c-calendar-metrics__label">Closures</span>
                </div>
              </div>

              <ol className="c-calendar-periods" aria-label="Prepared terms">
                {preview.periods.map((period) => (
                  <li className="c-calendar-periods__item" key={period.id}>
                    <span className="c-calendar-periods__sequence">
                      {period.sequence}
                    </span>
                    <span className="c-calendar-periods__copy">
                      <strong>{period.label}</strong>
                      <span className="c-calendar-periods__dates">
                        {formatDate(period.startOn)} – {formatDate(period.endOn)}
                      </span>
                    </span>
                  </li>
                ))}
              </ol>

              <div className="c-calendar-closures">
                <h3>Named closures</h3>
                <ul>
                  {preview.closures.map((closure) => (
                    <li className="c-calendar-closures__item" key={closure.id}>
                      <strong>{closure.label}</strong>
                      <span className="c-calendar-closures__date">
                        {formatDate(closure.date)}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            </Panel>

            <section className="c-date-check" aria-labelledby="date-check-title">
              <div className="c-date-check__heading">
                <div className="c-date-check__fact">
                  <p className="c-panel__eyebrow">Date resolution</p>
                  <h2 id="date-check-title">What does this date mean?</h2>
                </div>
                <StatusBadge
                  tone={resolution.status === "instructional" ? "positive" : "neutral"}
                >
                  {awaitingWriterResolution
                    ? "Not checked"
                    : resolution.status === "instructional"
                      ? "Instructional"
                      : "Non-instructional"}
                </StatusBadge>
              </div>
              <label className="c-field" htmlFor="resolution-date">
                <span className="c-field__label">Local calendar date</span>
                <input
                  className="c-input"
                  id="resolution-date"
                  type="date"
                  value={resolutionDate}
                  onChange={(event) => {
                    setResolutionDate(event.target.value);
                    setWriterResolution(null);
                  }}
                />
              </label>
              {connected && writerView?.status === "published" ? (
                <ActionButton
                  disabled={busy}
                  onClick={() => void guarded(resolveWriterDate)}
                  variant="secondary"
                >
                  Resolve date from database
                </ActionButton>
              ) : null}
              {awaitingWriterResolution ? (
                <p>
                  Resolve this date to read its meaning from the published calendar.
                </p>
              ) : (
                <dl className="c-date-check__result">
                  <div>
                    <dt>Reason</dt>
                    <dd>{reasonLabels[resolution.reason]}</dd>
                  </div>
                  {resolution.periodLabel ? (
                    <div className="c-date-check__fact">
                      <dt>Term</dt>
                      <dd>{resolution.periodLabel}</dd>
                    </div>
                  ) : null}
                  {resolution.closureLabel ? (
                    <div className="c-date-check__fact">
                      <dt>Closure</dt>
                      <dd>{resolution.closureLabel}</dd>
                    </div>
                  ) : null}
                </dl>
              )}
            </section>
          </div>
        </div>
      )}

      {!connected ? (
        <p className="u-visually-hidden" aria-live="polite" role="status">
          {announcement}
        </p>
      ) : null}
    </div>
  );
}
