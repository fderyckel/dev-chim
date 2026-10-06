"use client";

import { useEffect, useRef, useState } from "react";
import createClient from "openapi-fetch";
import type { components, paths } from "../generated/public/session-schema";
import { ActionButton } from "../design-system/components/actions";
import { PageHeading } from "../design-system/components/page-heading";
import { Panel } from "../design-system/components/panel";

type View = components["schemas"]["AttendanceView"];
type Classes = components["schemas"]["AssignedClassesResponse"]["data"];
type Input = Mutable<components["schemas"]["SubmitAttendanceRequest"]>;
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

export function ClassroomAttendance() {
  const [csrf, setCsrf] = useState<string | null>(null);
  const [classes, setClasses] = useState<Classes>([]);
  const [view, setView] = useState<View | null>(null);
  const [marks, setMarks] = useState<Record<string, Mark>>({});
  const [busy, setBusy] = useState(true);
  const [message, setMessage] = useState("Checking your session…");
  const [mustRefresh, setMustRefresh] = useState(false);
  const attempt = useRef<Input | null>(null);

  function clearSession() {
    setCsrf(null);
    setClasses([]);
    setView(null);
    setMarks({});
    attempt.current = null;
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
  async function session() {
    const result = await client.GET("/api/v1/session");
    if (!result.data) {
      clearSession();
      setMessage("Start a synthetic educator session to open your classes.");
      return;
    }
    const token = result.data.data.csrf_token;
    setCsrf(token);
    const assigned = await client.GET("/api/v1/classroom/classes");
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
    void Promise.resolve()
      .then(session)
      .catch(() => setMessage("The local classroom service is unavailable."))
      .finally(() => setBusy(false));
    // Only check the session on first arrival. Actions explicitly refresh current authority.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  async function guarded(action: () => Promise<void>) {
    setBusy(true);
    try {
      await action();
    } catch {
      setMustRefresh(true);
      setMessage("Connection interrupted. Reload the class to check what was saved.");
    } finally {
      setBusy(false);
    }
  }
  async function openClass(id: string) {
    if (!csrf) return;
    const result = await client.POST("/api/v1/classroom/prepare-attendance", {
      body: { class_id: id },
      params: { header: { Origin: window.location.origin, "X-CSRF-Token": csrf } },
    });
    if (!result.data) {
      setView(null);
      failure(result.response.status, result.error?.errors[0]?.code);
      return;
    }
    setView(result.data.data);
    setMarks({});
    setMustRefresh(false);
    attempt.current = null;
    setMessage(
      result.data.data.submission_id
        ? "Attendance saved. This is the register read back from the school database."
        : "Mark every student before submitting. No attendance is assumed.",
    );
  }
  async function submit() {
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
    if (!result.data) {
      failure(result.response.status, result.error?.errors[0]?.code);
      return;
    }
    await openClass(view.class_id);
  }
  const saved = !!view?.submission_id;
  const remaining = view?.students.filter((student) => !marks[student.id]).length ?? 0;
  return (
    <main className="c-classroom">
      <PageHeading
        eyebrow="Chimwemwe · classroom"
        title="Today’s attendance"
        description="Open your class, mark each student, and save the register."
        aside={<p>Synthetic educator · local evaluation</p>}
      />
      <p className="c-classroom__notice">
        Fictional people and a prepared class. Real school sign-in is not connected.
        Submitted attendance cannot yet be corrected.
      </p>
      <p className="c-classroom__message" role="status" aria-live="polite">
        {message}
      </p>
      {!csrf ? (
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
          Start synthetic educator session
        </ActionButton>
      ) : (
        <>
          <div className="c-classroom__actions">
            {classes.map((item) => (
              <ActionButton
                key={item.id}
                variant="secondary"
                disabled={busy}
                onClick={() => void guarded(() => openClass(item.id))}
              >
                {item.label}
              </ActionButton>
            ))}
            <ActionButton
              variant="quiet"
              disabled={busy}
              onClick={() =>
                void guarded(async () => {
                  const result = await client.POST("/api/v1/session/logout", {
                    headers: { "X-CSRF-Token": csrf },
                  });
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
                saved
                  ? "Saved register"
                  : `${view.students.length} students · ${remaining} still to mark`
              }
            >
              <form
                className="c-classroom__register"
                onSubmit={(event) => {
                  event.preventDefault();
                  void guarded(submit);
                }}
              >
                {view.students.map((student, index) => (
                  <fieldset
                    className="c-classroom__student"
                    key={student.id}
                    disabled={busy || saved || mustRefresh}
                  >
                    <legend>
                      {index + 1}. {student.name}
                    </legend>
                    {saved ? (
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
                  <ActionButton
                    variant="secondary"
                    disabled={busy}
                    onClick={() => void guarded(() => openClass(view.class_id))}
                  >
                    Reload class
                  </ActionButton>
                </div>
              </form>
            </Panel>
          )}
        </>
      )}
    </main>
  );
}
