"use client";

import { useState, type FormEvent } from "react";

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

type AcademicCalendarPreparationProps = Readonly<{
  viewData: AcademicCalendarPreparationViewData;
}>;

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

const reasonLabels = {
  closure: "Named closure",
  instructional_weekday: "Instructional weekday",
  ordinary_weekday_off: "Ordinary weekday off",
  outside_period: "Outside all terms",
  outside_year: "Outside this academic year",
} as const;

export function AcademicCalendarPreparation({
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

  const resolution = resolveCalendarDate(preview, resolutionDate);

  function changeDraft(next: AcademicCalendarDraft) {
    setDraft(next);
    setDirty(true);
    setErrors([]);
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

    setPreview(result.preview);
    setErrors([]);
    setDirty(false);
    setAnnouncement(
      `Preview updated with ${result.preview.instructionalDateCount} instructional dates. Nothing was saved.`,
    );
  }

  function resetExample() {
    setDraft(viewData.calendar);
    setPreview(initialPreview(viewData.calendar));
    setResolutionDate(viewData.initialResolutionDate);
    setErrors([]);
    setDirty(false);
    setAnnouncement("Synthetic example restored. Nothing was saved.");
  }

  return (
    <div className="l-page-stack">
      <PageHeading
        eyebrow="CF-2 · local preparation prototype"
        title="Prepare an academic calendar"
        description="Adjust a synthetic academic year, its terms, instructional weekdays, and closures. Preview the resulting dates before any connected writer exists."
        aside={
          <>
            <StatusBadge tone="attention">Not saved</StatusBadge>
            <span className="c-page-heading__assurance-copy">
              Local browser calculation · no core connection
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
            You can change every visible field and preview the result. This screen does
            not create an institution, save a draft, publish a year, or send data to the
            production core.
          </p>
        </div>
      </aside>

      <div className="l-calendar-workspace">
        <form className="c-calendar-form" onSubmit={previewCalendar}>
          <header className="c-calendar-form__header">
            <div>
              <p className="c-panel__eyebrow">Synthetic definition</p>
              <h2>Calendar details</h2>
              <p className="c-calendar-form__institution">
                {viewData.institution.label}
              </p>
            </div>
            <StatusBadge tone={dirty ? "attention" : "positive"}>
              {dirty ? "Changes not previewed" : "Preview current"}
            </StatusBadge>
          </header>

          <div className="c-calendar-form__body">
            <div className="l-calendar-fields">
              <label className="c-field" htmlFor="calendar-label">
                <span className="c-field__label">Academic year label</span>
                <input
                  className="c-input"
                  id="calendar-label"
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
                    <label className="c-field" htmlFor={`closure-${closure.id}-label`}>
                      <span className="c-field__label">Closure label</span>
                      <input
                        className="c-input"
                        id={`closure-${closure.id}-label`}
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
            <ActionButton type="submit" variant="primary">
              Preview calendar
            </ActionButton>
            <ActionButton onClick={resetExample} variant="secondary">
              Reset example
            </ActionButton>
            <p className="c-calendar-form__note">
              No save or publish action exists in this prototype.
            </p>
          </footer>
        </form>

        <div className="c-calendar-preview" aria-label="Prepared calendar preview">
          <Panel
            eyebrow="Prepared result"
            title={preview.definition.label}
            titleId="calendar-preview-title"
            badge={<StatusBadge tone="information">Local preview</StatusBadge>}
            footer={`Time zone: ${preview.definition.timeZone} · This result is not persisted.`}
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
                {resolution.status === "instructional"
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
                onChange={(event) => setResolutionDate(event.target.value)}
              />
            </label>
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
          </section>
        </div>
      </div>

      <p className="u-visually-hidden" aria-live="polite" role="status">
        {announcement}
      </p>
    </div>
  );
}
