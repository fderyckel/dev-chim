"use client";

import { useEffect, useRef, useState } from "react";
import { DraftDeparture } from "./classroom-departure";
import createClient from "openapi-fetch";
import type { components, paths } from "../generated/public/session-schema";
import { ActionButton, ActionLink } from "../design-system/components/actions";
import { PageHeading } from "../design-system/components/page-heading";
import { Panel } from "../design-system/components/panel";
import {
  StaffDestinations,
  StaffIdentity,
  staffRequest,
  StaffRequestError,
  type StaffPreference,
} from "./staff-shared";

type View = components["schemas"]["AttendanceView"];
type Classes = components["schemas"]["AssignedClassesResponse"]["data"];
type Input = Mutable<components["schemas"]["SubmitAttendanceRequest"]>;
type CorrectionInput = Mutable<components["schemas"]["CorrectAttendanceRequest"]>;
type Mark = Input["marks"][number]["mark"];
// openapi-fetch serializes mutable JSON arrays; keep the checked generated contract.
type Mutable<T> = T extends readonly (infer U)[]
  ? Mutable<U>[]
  : T extends object
    ? { -readonly [K in keyof T]: Mutable<T[K]> }
    : T;
const client = createClient<Mutable<paths>>({
  credentials: "same-origin",
  cache: "no-store",
});
const markLabels = { present: "Present", absent: "Absent", late: "Late" } as const;
const oidcSignInEnabled = process.env.NEXT_PUBLIC_CHIMWEMWE_OIDC_SIGN_IN === "true";

export function ClassroomAttendance({
  staffSignIn = false,
}: { staffSignIn?: boolean } = {}) {
  const [csrf, setCsrf] = useState<string | null>(null);
  const [presentation, setPresentation] = useState<StaffPreference | null>(null);
  const [classes, setClasses] = useState<Classes>([]);
  const [view, setView] = useState<View | null>(null);
  const [marks, setMarks] = useState<Record<string, Mark>>({});
  const [correcting, setCorrecting] = useState(false);
  const [busy, setBusy] = useState(true);
  const [message, setMessage] = useState("Checking your session…");
  const [mustRefresh, setMustRefresh] = useState(false);
  const generation = useRef(0);
  const active = useRef(false);
  const bypassUnload = useRef(false);
  const [taskMenuOpen, setTaskMenuOpen] = useState(false);
  const [departure, setDeparture] = useState<{
    action: () => void;
    origin: HTMLElement | null;
  } | null>(null);
  const attempt = useRef<Input | null>(null);
  const correctionAttempt = useRef<CorrectionInput | null>(null);

  function clearSession() {
    setCsrf(null);
    setPresentation(null);
    setClasses([]);
    setView(null);
    setMarks({});
    setCorrecting(false);
    setMustRefresh(false);
    setDeparture(null);
    attempt.current = null;
    correctionAttempt.current = null;
  }
  function failure(status: number, code?: string) {
    if (status === 401 || status === 403) {
      clearSession();
      setMessage("Your access is no longer current. Sign in again.");
    } else {
      setMustRefresh(true);
      setMessage(
        code === "non_instructional"
          ? "Today is not an instructional day for this class."
          : code === "scope_limit"
            ? "This register is empty or exceeds the local review limit."
            : status === 409
              ? "This register has changed. Reload the class before continuing."
              : "We could not confirm the result. Reload the class to check what was saved.",
      );
    }
  }
  async function session(current: () => boolean) {
    clearSession();
    const result = await client.GET("/api/v1/session");
    if (!current()) return;
    if (!result.data) {
      clearSession();
      setMessage(
        staffSignIn
          ? "Sign in with your individual staff account to open your classes."
          : oidcSignInEnabled
            ? "Sign in with your school account to open your classes."
            : "Start a synthetic educator session to open your classes.",
      );
      return;
    }
    const token = result.data.data.csrf_token;
    setCsrf(token);
    if (staffSignIn) {
      const own = await staffRequest<StaffPreference>("/api/v1/staff-preferences");
      if (!current()) return;
      setPresentation(own);
      if (own.navigation?.classroom !== true) {
        setClasses([]);
        setMessage("Classroom access is not available for this account.");
        return;
      }
    }
    const assigned = await client.GET("/api/v1/classroom/classes");
    if (!current()) return;
    if (!assigned.data) {
      failure(assigned.response.status);
      return;
    }
    setClasses(assigned.data.data);
    setMessage(
      assigned.data.data.length
        ? "Choose a class to open today’s register."
        : "No classes are assigned to you today.",
    );
  }
  useEffect(() => {
    active.current = true;
    const arrival = ++generation.current;
    void Promise.resolve().then(() => {
      if (active.current && generation.current === arrival) void guarded(session);
    });
    const invalidate = () => {
      active.current = false;
      generation.current++;
    };
    const resume = (event: PageTransitionEvent) => {
      if (event.persisted) window.location.reload();
    };
    const leave = () => {
      active.current = false;
      generation.current++;
      clearSession();
    };
    window.addEventListener("pageshow", resume);
    window.addEventListener("pagehide", leave);
    return () => {
      invalidate();
      window.removeEventListener("pageshow", resume);
      window.removeEventListener("pagehide", leave);
    };
    // Every arrival gets a new lifetime; actions recheck writer-owned authority.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  async function guarded(action: (current: () => boolean) => Promise<void>) {
    if (!active.current) return;
    const request = ++generation.current;
    const current = () => active.current && generation.current === request;
    setBusy(true);
    try {
      await action(current);
    } catch (error) {
      if (!current()) return;
      if (error instanceof StaffRequestError && [401, 403].includes(error.status)) {
        failure(error.status);
      } else {
        setMustRefresh(true);
        setMessage("Connection interrupted. Reload the class to check what was saved.");
      }
    } finally {
      if (current()) setBusy(false);
    }
  }
  async function openClass(
    id: string,
    current: () => boolean,
    confirmedCorrection = false,
  ) {
    if (!csrf) return;
    const result = await client.POST("/api/v1/classroom/prepare-attendance", {
      body: { class_id: id },
      params: { header: { Origin: window.location.origin, "X-CSRF-Token": csrf } },
    });
    if (!current()) return;
    if (!result.data) {
      // Retain the opened date and pending request for honest reconciliation.
      if (result.response.status === 401 || result.response.status === 403)
        setView(null);
      failure(result.response.status, result.error?.errors[0]?.code);
      return;
    }
    const loaded = result.data.data;
    if (
      view?.class_id === id &&
      loaded.local_date !== view.local_date &&
      (attempt.current || correctionAttempt.current)
    ) {
      setMustRefresh(true);
      setMessage(
        `The opened register is for ${view.local_date}. Today's read is for ${loaded.local_date} and cannot confirm the earlier result. Do not retry it here; ask an authorized records administrator to follow up.`,
      );
      return;
    }
    const pendingCorrection =
      correctionAttempt.current?.class_id === loaded.class_id &&
      correctionAttempt.current.submission_id === loaded.submission_id
        ? correctionAttempt.current
        : null;
    const pendingMarksAreCurrent =
      !!pendingCorrection &&
      loaded.students.every((student) =>
        pendingCorrection.marks.some(
          (mark) => mark.person_id === student.id && mark.mark === student.mark,
        ),
      );
    setView(loaded);
    setTaskMenuOpen(false);
    requestAnimationFrame(() => document.getElementById("attendance-task")?.focus());
    setMustRefresh(false);
    attempt.current = null;
    if (
      pendingCorrection &&
      loaded.revision_id === pendingCorrection.expected_revision_id
    ) {
      setCorrecting(true);
      setMarks(
        Object.fromEntries(
          pendingCorrection.marks.map((item) => [item.person_id, item.mark]),
        ),
      );
      setMessage(
        "No correction was saved. Review the marks and retry the same request.",
      );
    } else {
      correctionAttempt.current = null;
      setCorrecting(false);
      setMarks({});
      if (pendingCorrection && !confirmedCorrection) {
        setMessage(
          pendingMarksAreCurrent
            ? `The requested marks are current in attendance correction ${loaded.correction_number}.`
            : "The register changed before your correction was confirmed. Review the current saved marks before correcting again.",
        );
      } else {
        setMessage(
          loaded.submission_id
            ? loaded.correction_number > 0
              ? `Attendance correction ${loaded.correction_number} saved and read back from the school database.`
              : "Attendance saved. This is the register read back from the school database."
            : "Mark every student before submitting. No attendance is assumed.",
        );
      }
    }
  }

  function requestDeparture(action: () => void) {
    if (
      busy ||
      (mustRefresh && (view || attempt.current || correctionAttempt.current))
    ) {
      setMessage(
        busy
          ? "Wait for the current request to finish. Sign out remains available."
          : "Reload the current class to reconcile the result before leaving. Sign out remains available; leaving does not cancel a request.",
      );
      return;
    }
    if (unsaved) {
      setDeparture({
        action,
        origin:
          document.activeElement instanceof HTMLElement ? document.activeElement : null,
      });
    } else {
      attempt.current = null;
      correctionAttempt.current = null;
      action();
    }
  }
  function chooseClass(id: string) {
    if (id === view?.class_id) return;
    requestDeparture(() => void guarded((current) => openClass(id, current)));
  }
  async function submit(current: () => boolean) {
    if (!view || !csrf) return;
    const body: Input = attempt.current ?? {
      class_id: view.class_id,
      local_date: view.local_date,
      calendar_revision: view.calendar_revision,
      roster_basis: view.roster_basis,
      idempotency_key: crypto.randomUUID(),
      causation_id: crypto.randomUUID(),
      marks: view.students.map((student) => ({
        person_id: student.id,
        mark: marks[student.id],
      })),
    };
    attempt.current = body;
    const result = await client.POST("/api/v1/classroom/submit-attendance", {
      body,
      params: { header: { Origin: window.location.origin, "X-CSRF-Token": csrf } },
    });
    if (!current()) return;
    if (!result.data) {
      failure(result.response.status, result.error?.errors[0]?.code);
      return;
    }
    await openClass(view.class_id, current);
  }
  function startCorrection() {
    if (!view?.submission_id || !view.revision_id) return;
    correctionAttempt.current = null;
    setMarks(
      Object.fromEntries(
        view.students.flatMap((student) =>
          student.mark ? [[student.id, student.mark] as const] : [],
        ),
      ),
    );
    setCorrecting(true);
    setMessage(
      "Review the saved marks. Change at least one mark before saving the correction.",
    );
  }
  function cancelCorrection() {
    if (mustRefresh || busy) return;
    correctionAttempt.current = null;
    setMarks({});
    setCorrecting(false);
    setMessage("Correction cancelled. The saved register is unchanged.");
  }
  async function correct(current: () => boolean) {
    if (!view?.submission_id || !view.revision_id || !csrf) return;
    const body: CorrectionInput = correctionAttempt.current ?? {
      class_id: view.class_id,
      submission_id: view.submission_id,
      expected_revision_id: view.revision_id,
      reason_code: "marking_error",
      idempotency_key: crypto.randomUUID(),
      causation_id: crypto.randomUUID(),
      marks: view.students.map((student) => ({
        person_id: student.id,
        mark: marks[student.id],
      })),
    };
    correctionAttempt.current = body;
    const result = await client.POST("/api/v1/classroom/correct-attendance", {
      body,
      params: { header: { Origin: window.location.origin, "X-CSRF-Token": csrf } },
    });
    if (!current()) return;
    if (!result.data) {
      failure(result.response.status, result.error?.errors[0]?.code);
      return;
    }
    await openClass(view.class_id, current, true);
  }
  const saved = !!view?.submission_id;
  const remaining = view?.students.filter((student) => !marks[student.id]).length ?? 0;
  const changed =
    !!view &&
    correcting &&
    view.students.some((student) => marks[student.id] !== student.mark);
  const unsaved =
    !!view && (correcting ? changed : !saved && Object.keys(marks).length > 0);
  useEffect(() => {
    if (!unsaved && !mustRefresh && !busy) return;
    const warn = (event: BeforeUnloadEvent) => {
      if (!bypassUnload.current) {
        event.preventDefault();
        event.returnValue = "";
      }
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [unsaved, mustRefresh, busy]);
  const ambiguous = new Set(
    classes
      .filter((item) =>
        classes.some(
          (other) =>
            other.id !== item.id &&
            other.label.trim().replace(/\s+/gu, " ") ===
              item.label.trim().replace(/\s+/gu, " ") &&
            other.local_date === item.local_date,
        ),
      )
      .map((item) => item.id),
  );
  return (
    <main
      className="c-classroom"
      onClickCapture={(event) => {
        if (
          event.button !== 0 ||
          event.metaKey ||
          event.ctrlKey ||
          event.shiftKey ||
          event.altKey
        )
          return;
        const link = (event.target as HTMLElement).closest<HTMLAnchorElement>(
          "a[href]",
        );
        if (
          !link ||
          link.target === "_blank" ||
          link.getAttribute("href")?.startsWith("#")
        )
          return;
        event.preventDefault();
        event.stopPropagation();
        requestDeparture(() => {
          bypassUnload.current = true;
          window.location.assign(link.href);
        });
      }}
    >
      <PageHeading
        eyebrow="Chimwemwe · classroom"
        title={staffSignIn ? "Classroom" : "Today’s attendance"}
        description={
          staffSignIn
            ? "Mark each student, then save."
            : "Open your class, mark each student, and save the register."
        }
        aside={
          <div>
            {staffSignIn && <StaffIdentity locale="en" presentation={presentation} />}
            <p>
              {staffSignIn
                ? "Fictional staff · local evaluation"
                : oidcSignInEnabled
                  ? "Educator · school account"
                  : "Synthetic educator · local evaluation"}
            </p>
          </div>
        }
      />
      <p className="c-classroom__notice">
        {staffSignIn ? (
          "Today’s assigned classes only. Corrections keep earlier records."
        ) : (
          <>
            {oidcSignInEnabled
              ? "School account sign-in is available for the pre-linked educator configured by this deployment. "
              : "Fictional people and a prepared class. Real school sign-in is not connected. "}
            Corrections are limited to today’s assigned class and retain every earlier
            register.
          </>
        )}
      </p>
      <div className="c-classroom__actions">
        {staffSignIn ? (
          csrf && (
            <>
              <StaffDestinations locale="en" presentation={presentation} />
            </>
          )
        ) : (
          <ActionLink href="/classroom/setup" variant="secondary" icon="forward">
            Prepare a class
          </ActionLink>
        )}
      </div>
      {csrf && (
        <nav className="c-classroom__tasks" aria-label="Classroom tasks">
          <ActionButton
            variant="secondary"
            ariaExpanded={taskMenuOpen}
            ariaControls="classroom-task-items"
            ariaLabel={`Classroom tasks: ${view ? "Attendance" : "My classes"}`}
            onClick={() => setTaskMenuOpen(!taskMenuOpen)}
          >
            Classroom · {view ? "Attendance" : "My classes"} ▾
          </ActionButton>
          <div
            id="classroom-task-items"
            className="c-classroom__task-items"
            data-open={taskMenuOpen}
          >
            <button
              type="button"
              aria-current={!view ? "page" : undefined}
              onClick={() =>
                requestDeparture(() => {
                  setView(null);
                  setMarks({});
                  setCorrecting(false);
                  setTaskMenuOpen(false);
                  requestAnimationFrame(() =>
                    document.getElementById("my-classes-title")?.focus(),
                  );
                })
              }
            >
              My classes
            </button>
            <button
              type="button"
              aria-current={view ? "page" : undefined}
              disabled={!view}
              onClick={() => {
                setTaskMenuOpen(false);
                document.getElementById("attendance-task")?.focus();
              }}
            >
              Attendance
            </button>
          </div>
        </nav>
      )}
      <p className="c-classroom__message" role="status" aria-live="polite">
        {message}
      </p>
      {!csrf ? (
        staffSignIn ? (
          <div className="c-classroom__actions">
            <ActionLink href="/sign-in">Sign in</ActionLink>
            {!busy && (
              <ActionButton variant="secondary" onClick={() => void guarded(session)}>
                Try again
              </ActionButton>
            )}
          </div>
        ) : oidcSignInEnabled ? (
          <ActionLink href="/auth/sign-in">Sign in with your school account</ActionLink>
        ) : (
          <ActionButton
            disabled={busy}
            onClick={() =>
              void guarded(async (current) => {
                const result = await fetch("/api/v1/classroom-demo/sign-in", {
                  method: "POST",
                  headers: { "Content-Type": "application/json" },
                  body: "{}",
                  cache: "no-store",
                });
                if (!current()) return;
                if (!result.ok) throw new Error("Sign-in unavailable");
                await session(current);
              })
            }
          >
            Start synthetic educator session
          </ActionButton>
        )
      ) : (
        <>
          <section aria-labelledby="my-classes-title">
            <h2 id="my-classes-title" tabIndex={-1}>
              My classes
            </h2>
            {ambiguous.size > 0 && (
              <p role="alert">
                Some class labels and dates are identical. Ask your administrator to
                clarify their labels before opening them.
              </p>
            )}
            <div className="c-classroom__actions">
              {classes.map((item) => (
                <div key={item.id} className="c-classroom__class-choice">
                  <ActionButton
                    variant="secondary"
                    ariaDescribedBy={`class-date-${item.id}`}
                    disabled={busy || ambiguous.has(item.id)}
                    onClick={() => chooseClass(item.id)}
                  >
                    {item.label}
                  </ActionButton>
                  <p id={`class-date-${item.id}`}>{item.local_date}</p>
                </div>
              ))}
            </div>
          </section>
          <div className="c-classroom__actions">
            {!view && (
              <ActionButton
                variant="secondary"
                disabled={busy}
                onClick={() => void guarded(session)}
              >
                Reload my classes
              </ActionButton>
            )}
            <ActionButton
              variant="quiet"
              onClick={() =>
                void guarded(async (current) => {
                  const result = await client.POST("/api/v1/session/logout", {
                    headers: { "X-CSRF-Token": csrf },
                  });
                  if (!current()) return;
                  if (result.response.status !== 204) {
                    failure(result.response.status);
                    return;
                  }
                  clearSession();
                  setMessage("Signed out.");
                })
              }
            >
              Sign out
            </ActionButton>
          </div>
          {view && (
            <Panel
              eyebrow={view.local_date}
              title={view.label}
              titleId="class-title"
              description={
                correcting
                  ? mustRefresh
                    ? "Correction result unconfirmed"
                    : busy
                      ? "Saving correction…"
                      : "Unsaved correction"
                  : mustRefresh
                    ? "Result unconfirmed"
                    : saved
                      ? "Saved register"
                      : `${view.students.length} ${view.students.length === 1 ? "student" : "students"} · ${remaining} still to mark`
              }
            >
              <form
                className="c-classroom__register"
                onSubmit={(event) => {
                  event.preventDefault();
                  if (
                    busy ||
                    mustRefresh ||
                    remaining > 0 ||
                    (saved && !correcting) ||
                    (correcting && !changed)
                  )
                    return;
                  void guarded(correcting ? correct : submit);
                }}
              >
                <h3 id="attendance-task" tabIndex={-1}>
                  Attendance · {view.label} · {view.local_date}
                </h3>
                {mustRefresh && (
                  <p>
                    Result unconfirmed. Reload class before continuing. Signing out does
                    not cancel a request already sent.
                  </p>
                )}
                {correcting && (
                  <p className="c-classroom__correction-note">
                    Reason: marking error. The submitted register will remain in the
                    correction history.
                  </p>
                )}
                {view.students.map((student, index) => (
                  <fieldset
                    className="c-classroom__student"
                    key={student.id}
                    disabled={busy || (saved && !correcting) || mustRefresh}
                  >
                    <legend>
                      {index + 1}. {student.name}
                    </legend>
                    {saved && !correcting ? (
                      <p>{student.mark ? markLabels[student.mark] : "Unmarked"}</p>
                    ) : (
                      <div className="c-classroom__marks">
                        {(Object.keys(markLabels) as Mark[]).map((mark) => (
                          <label key={mark}>
                            <input
                              type="radio"
                              name={student.id}
                              value={mark}
                              checked={marks[student.id] === mark}
                              onChange={() => {
                                setMarks((previous) => ({
                                  ...previous,
                                  [student.id]: mark,
                                }));
                                attempt.current = null;
                                correctionAttempt.current = null;
                              }}
                            />
                            {markLabels[mark]}
                          </label>
                        ))}
                      </div>
                    )}
                  </fieldset>
                ))}
                <div className="c-classroom__actions">
                  {!saved && (
                    <ActionButton
                      type="submit"
                      disabled={busy || remaining > 0 || mustRefresh}
                    >
                      {busy ? "Saving…" : "Submit attendance"}
                    </ActionButton>
                  )}
                  {saved && !correcting && (
                    <ActionButton
                      type="button"
                      disabled={busy || mustRefresh || view.correction_number >= 10}
                      onClick={startCorrection}
                    >
                      Correct attendance
                    </ActionButton>
                  )}
                  {correcting && (
                    <>
                      <ActionButton
                        type="submit"
                        disabled={busy || remaining > 0 || !changed || mustRefresh}
                      >
                        {busy ? "Saving…" : "Save correction"}
                      </ActionButton>
                      <ActionButton
                        type="button"
                        variant="quiet"
                        disabled={busy || mustRefresh}
                        onClick={cancelCorrection}
                      >
                        Cancel correction
                      </ActionButton>
                    </>
                  )}
                  <ActionButton
                    variant="secondary"
                    disabled={busy}
                    onClick={() => {
                      const reload = () =>
                        void guarded((current) => openClass(view.class_id, current));
                      if (mustRefresh) reload();
                      else requestDeparture(reload);
                    }}
                  >
                    Reload class
                  </ActionButton>
                </div>
              </form>
            </Panel>
          )}
        </>
      )}
      {departure && (
        <DraftDeparture
          onStay={() => {
            const origin = departure.origin;
            setDeparture(null);
            requestAnimationFrame(() => origin?.focus());
          }}
          onDiscard={() => {
            const action = departure.action;
            setDeparture(null);
            setMarks({});
            setCorrecting(false);
            attempt.current = null;
            correctionAttempt.current = null;
            bypassUnload.current = true;
            action();
            // Local task changes keep the next draft protected too.
            queueMicrotask(() => {
              bypassUnload.current = false;
            });
          }}
        />
      )}
    </main>
  );
}
