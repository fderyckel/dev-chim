"use client";

import { useEffect, useRef, useState } from "react";
import createClient from "openapi-fetch";
import type { components, paths } from "../generated/public/session-schema";
import { ActionButton, ActionLink } from "../design-system/components/actions";
import { PageHeading } from "../design-system/components/page-heading";
import { Panel } from "../design-system/components/panel";

type Mutable<T> = T extends readonly (infer U)[]
  ? Mutable<U>[]
  : T extends object
    ? { -readonly [K in keyof T]: Mutable<T[K]> }
    : T;
type View = components["schemas"]["ClassroomPreparationView"];
type ClassInput = Mutable<components["schemas"]["PrepareClassRequest"]>;
type StudentInput = Mutable<components["schemas"]["AddStudentRequest"]>;

const client = createClient<Mutable<paths>>({
  credentials: "same-origin",
  cache: "no-store",
});

export function ClassroomPreparation() {
  const [csrf, setCsrf] = useState<string | null>(null);
  const [view, setView] = useState<View | null>(null);
  const [classLabel, setClassLabel] = useState("Year 6 Blue");
  const [classCode, setClassCode] = useState("year_6_blue");
  const [studentName, setStudentName] = useState("");
  const [busy, setBusy] = useState(true);
  const [message, setMessage] = useState("Checking your session…");
  const classAttempt = useRef<ClassInput | null>(null);
  const studentAttempt = useRef<StudentInput | null>(null);

  function clearSession() {
    setCsrf(null);
    setView(null);
    classAttempt.current = null;
    studentAttempt.current = null;
  }

  function failure(status: number, code?: string) {
    if (status === 401 || status === 403) {
      clearSession();
      setMessage("Your access is no longer current. Sign in again.");
    } else {
      setMessage(
        code === "scope_limit"
          ? "This local class already has the maximum 60 fictional students."
          : status === 409
            ? "The preparation workspace changed. Reload it before continuing."
            : "We could not confirm the result. Reload the workspace to check what was saved.",
      );
    }
  }

  async function loadWorkspace(token?: string) {
    let currentToken = token ?? csrf;
    if (!currentToken) {
      const session = await client.GET("/api/v1/session");
      if (!session.data) {
        clearSession();
        setMessage("Start a synthetic administrator session to prepare the class.");
        return;
      }
      currentToken = session.data.data.csrf_token;
      setCsrf(currentToken);
    }

    const result = await client.GET("/api/v1/classroom/preparation");
    if (!result.data) {
      failure(result.response.status, result.error?.errors[0]?.code);
      return;
    }
    setView(result.data.data);
    setMessage(
      result.data.data.class
        ? "This is the current class preparation read back from the school database."
        : "Name the class to begin. The school year and educator are already bound on the server.",
    );
  }

  useEffect(() => {
    void Promise.resolve()
      .then(() => loadWorkspace())
      .catch(() => setMessage("The local classroom service is unavailable."))
      .finally(() => setBusy(false));
    // Check the session only on first arrival; every action revalidates it on the writer.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function guarded(action: () => Promise<void>) {
    setBusy(true);
    try {
      await action();
    } catch {
      setMessage(
        "Connection interrupted. Reload the workspace to check what was saved.",
      );
    } finally {
      setBusy(false);
    }
  }

  async function startSession() {
    const response = await fetch("/api/v1/classroom-demo/sign-in", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}",
      cache: "no-store",
    });
    if (!response.ok) throw new Error("Sign-in unavailable");
    await loadWorkspace();
  }

  async function prepareClass() {
    if (!csrf) return;
    const body: ClassInput = classAttempt.current ?? {
      label: classLabel,
      code: classCode,
      idempotency_key: crypto.randomUUID(),
      causation_id: crypto.randomUUID(),
    };
    classAttempt.current = body;
    const result = await client.POST("/api/v1/classroom/prepare-class", {
      body,
      params: { header: { Origin: window.location.origin, "X-CSRF-Token": csrf } },
    });
    if (!result.data) {
      failure(result.response.status, result.error?.errors[0]?.code);
      return;
    }
    classAttempt.current = null;
    setView(result.data.data);
    setMessage("Class and educator assignment saved together.");
  }

  async function addStudent() {
    if (!csrf) return;
    const body: StudentInput = studentAttempt.current ?? {
      display_name: studentName,
      idempotency_key: crypto.randomUUID(),
      causation_id: crypto.randomUUID(),
    };
    studentAttempt.current = body;
    const result = await client.POST("/api/v1/classroom/add-student", {
      body,
      params: { header: { Origin: window.location.origin, "X-CSRF-Token": csrf } },
    });
    if (!result.data) {
      failure(result.response.status, result.error?.errors[0]?.code);
      return;
    }
    studentAttempt.current = null;
    setStudentName("");
    setView(result.data.data);
    setMessage("Student, enrolment, and class placement saved together.");
  }

  return (
    <main className="c-classroom">
      <PageHeading
        eyebrow="Chimwemwe · classroom preparation"
        title="Prepare a class"
        description="Create one class, assign its educator, and add fictional students."
        aside={<p>Synthetic administrator · local evaluation</p>}
      />
      <p className="c-classroom__notice">
        The institution, published school year, and educator are fixed by the server.
        Real school sign-in and real student records are not connected.
      </p>
      <p className="c-classroom__message" role="status" aria-live="polite">
        {message}
      </p>

      {!csrf ? (
        <ActionButton disabled={busy} onClick={() => void guarded(startSession)}>
          Start synthetic administrator session
        </ActionButton>
      ) : (
        <>
          {view && (
            <Panel
              eyebrow={view.academic_year_label}
              title={view.institution_name}
              titleId="preparation-scope"
              description={`Assigned educator: ${view.educator_name}`}
            >
              {!view.class ? (
                <form
                  className="c-classroom__form"
                  onSubmit={(event) => {
                    event.preventDefault();
                    void guarded(prepareClass);
                  }}
                >
                  <label>
                    Class name
                    <input
                      className="c-input"
                      value={classLabel}
                      maxLength={160}
                      required
                      onChange={(event) => {
                        setClassLabel(event.target.value);
                        classAttempt.current = null;
                      }}
                    />
                  </label>
                  <label>
                    Short code
                    <input
                      className="c-input"
                      value={classCode}
                      maxLength={80}
                      pattern="[a-z][a-z0-9_]*"
                      required
                      onChange={(event) => {
                        setClassCode(event.target.value);
                        classAttempt.current = null;
                      }}
                    />
                  </label>
                  <ActionButton type="submit" disabled={busy}>
                    {busy ? "Saving…" : "Create class and assign educator"}
                  </ActionButton>
                </form>
              ) : (
                <div className="c-classroom__prepared">
                  <div>
                    <p className="c-classroom__class-code">{view.class.code}</p>
                    <h3>{view.class.label}</h3>
                    <p>{view.students.length} fictional students</p>
                  </div>
                  <form
                    className="c-classroom__form"
                    onSubmit={(event) => {
                      event.preventDefault();
                      void guarded(addStudent);
                    }}
                  >
                    <label>
                      Student display name
                      <input
                        className="c-input"
                        value={studentName}
                        maxLength={200}
                        required
                        autoComplete="off"
                        onChange={(event) => {
                          setStudentName(event.target.value);
                          studentAttempt.current = null;
                        }}
                      />
                    </label>
                    <ActionButton
                      type="submit"
                      disabled={busy || view.students.length >= 60}
                    >
                      {busy ? "Saving…" : "Add student to class"}
                    </ActionButton>
                  </form>
                  {view.students.length > 0 && (
                    <ol
                      className="c-classroom__student-list"
                      aria-label="Prepared students"
                    >
                      {view.students.map((student) => (
                        <li key={student.id}>{student.name}</li>
                      ))}
                    </ol>
                  )}
                  <div className="c-classroom__actions">
                    <ActionLink href="/classroom" icon="forward">
                      Open today’s attendance
                    </ActionLink>
                    <ActionButton
                      variant="secondary"
                      disabled={busy}
                      onClick={() => void guarded(() => loadWorkspace())}
                    >
                      Reload workspace
                    </ActionButton>
                  </div>
                </div>
              )}
            </Panel>
          )}
          <div className="c-classroom__actions">
            <ActionLink
              href="/classroom"
              variant="quiet"
              icon="back"
              iconPosition="before"
            >
              Back to attendance
            </ActionLink>
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
        </>
      )}
    </main>
  );
}
