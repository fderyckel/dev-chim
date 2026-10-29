"use client";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { ActionButton, ActionLink } from "../design-system/components/actions";
import { PageHeading } from "../design-system/components/page-heading";
import { Panel } from "../design-system/components/panel";
import {
  clearNoticeCommand,
  noticeCommandDigest,
  restoreNoticeCommand,
  retainNoticeCommand,
  type PendingNoticeCommand,
} from "../lib/communications-recovery";
import { CommunicationsProofPersonas } from "./communications-proof-personas";
import { staffSession } from "./staff-shared";
import {
  commandPath,
  noticeMessage,
  noticeRequest,
  NoticeError,
  references,
  type Command,
  type Notice,
  type Outcome,
} from "../lib/communications-client";

type Mode = "write" | "review" | "notice" | "metrics";
const statement = "I acknowledge receipt of this notice.";

export function CommunicationsWorkspace({
  noticeId,
  mode,
}: {
  noticeId?: string;
  mode: Mode;
}) {
  const [view, setView] = useState<Notice | null>(null);
  const [prepared, setPrepared] = useState<Notice | null>(null);
  const [opened, setOpened] = useState<Notice | null>(null);
  const [institution, setInstitution] = useState<string | null>(null);
  const [csrf, setCsrf] = useState<string | null>(null);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [receipt, setReceipt] = useState(false);
  const [reason, setReason] = useState("");
  const [operation, setOperation] = useState<"publish" | "correct" | "withdraw">(
    "publish",
  );
  const [busy, setBusy] = useState(true);
  const [pending, setPending] = useState<PendingNoticeCommand | null>(null);
  const [checkedAbsent, setCheckedAbsent] = useState(false);
  const [resumeText, setResumeText] = useState(false);
  const [needsRefresh, setNeedsRefresh] = useState(false);
  const [blockedPreparation, setBlockedPreparation] = useState<string | null>(null);
  const [message, setMessage] = useState("");
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [dirty, setDirty] = useState(false);
  const feedback = useRef<HTMLDivElement>(null);
  const generation = useRef(0);
  const id = view?.notice_id ?? noticeId;
  const withdrawn = view?.state === "withdrawn";
  const recipientMode = mode === "notice";
  function clearProtected() {
    setInstitution(null);
    setView(null);
    setOpened(null);
    setPrepared(null);
    setCsrf(null);
  }
  function report(error: unknown) {
    if (error instanceof NoticeError && (error.status === 401 || error.status === 403))
      clearProtected();
    setMessage(noticeMessage(error, recipientMode));
    requestAnimationFrame(() => feedback.current?.focus());
  }
  async function load(selectedId?: string) {
    const epoch = ++generation.current;
    setBusy(true);
    setOpened(null);
    setPrepared(null);
    const restored = restoreNoticeCommand();
    if (restored) setPending((current) => current ?? restored);
    const blocked = new URLSearchParams(window.location.hash.slice(1)).get(
      "stale-preparation",
    );
    if (blocked && /^[0-9a-f-]{36}$/i.test(blocked)) setBlockedPreparation(blocked);
    try {
      const session = await staffSession();
      if (epoch !== generation.current) return;
      setCsrf(session.csrf_token);
      const target = selectedId ?? noticeId ?? view?.notice_id;
      if (target) {
        const path =
          mode === "write"
            ? "draft"
            : mode === "review"
              ? "review"
              : mode === "metrics"
                ? "metrics"
                : "status";
        const query: Record<string, string> = { notice_id: target };
        if (mode === "metrics") {
          const revision = new URL(window.location.href).searchParams.get("revision");
          if (!revision) throw new NoticeError(400);
          query.revision_id = revision;
        }
        const current = await noticeRequest<Notice>(
          ("/api/v1/communications/" + path) as "/api/v1/communications/status",
          undefined,
          undefined,
          query,
        );
        if (epoch !== generation.current) return;
        setView(current);
        setInstitution(current.institution ?? null);
        setTitle(current.title ?? "");
        setBody(current.body ?? "");
        setReceipt(current.receipt_required ?? false);
        setOperation(current.number ? "correct" : "publish");
        setDirty(false);
      } else if (mode === "write") {
        const scope = await noticeRequest<{ institution: string }>(
          "/api/v1/communications/workspace",
        );
        if (epoch !== generation.current) return false;
        setInstitution(scope.institution);
      }
      if (!target && restored?.metadataOnly) {
        setReceipt(restored.body.receipt_required === true);
        const kind = restored.body.operation;
        if (kind === "publish" || kind === "correct" || kind === "withdraw")
          setOperation(kind);
      }
      setNeedsRefresh(false);
      setMessage(
        restored ? "An earlier request needs to be checked before you continue." : "",
      );
      return true;
    } catch (error) {
      if (epoch !== generation.current) return;
      clearProtected();
      report(error);
      return false;
    } finally {
      if (epoch === generation.current) setBusy(false);
    }
  }
  useEffect(() => {
    void Promise.resolve().then(() => load());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [noticeId, mode]);
  useEffect(() => {
    const clear = () => {
      generation.current++;
      clearProtected();
    };
    const restore = (event: PageTransitionEvent) => {
      if (event.persisted) window.location.reload();
    };
    window.addEventListener("pagehide", clear);
    window.addEventListener("pageshow", restore);
    return () => {
      window.removeEventListener("pagehide", clear);
      window.removeEventListener("pageshow", restore);
    };
  }, []);
  useEffect(() => {
    const warn = (event: BeforeUnloadEvent) => {
      if (pending) {
        event.preventDefault();
        event.returnValue = "";
      }
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [pending]);
  function changed(field?: "title" | "body" | "reason") {
    setPrepared(null);
    setDirty(true);
    setMessage("");
    if (field)
      setFieldErrors((current) => {
        const next = { ...current };
        delete next[field];
        return next;
      });
  }
  function validateContent() {
    const errors: Record<string, string> = {};
    if (!title.trim() || Array.from(title).length > 120)
      errors.title = "Use a title of 1 to 120 characters.";
    if (!body.trim() || Array.from(body).length > 2000)
      errors.body = "Use a body of 1 to 2,000 characters.";
    if (operation !== "publish" && (!reason.trim() || Array.from(reason).length > 240))
      errors.reason = "Give a reason of 1 to 240 characters.";
    setFieldErrors(errors);
    if (Object.keys(errors).length) {
      setMessage("Check the highlighted fields.");
      requestAnimationFrame(() => feedback.current?.focus());
      return false;
    }
    return true;
  }
  async function execute(command: Command, retry = false) {
    if (!csrf || (pending && !retry)) return;
    const epoch = ++generation.current;
    setBusy(true);
    setMessage("");
    setCheckedAbsent(false);
    setResumeText(false);
    let exact: PendingNoticeCommand | undefined;
    try {
      const digest = await noticeCommandDigest(command);
      if (epoch !== generation.current) return;
      if (retry && pending?.digest !== digest) {
        setResumeText(true);
        setCheckedAbsent(true);
        setMessage(
          "This text does not match the original request. Re-enter the original text to retry safely.",
        );
        return;
      }
      exact = { ...command, digest };
      retainNoticeCommand(exact);
      setPending(exact);
      const result = await noticeRequest<Notice>(
        commandPath(command.name),
        command.body,
        csrf,
      );
      if (epoch !== generation.current) return;
      clearNoticeCommand();
      setPending(null);
      accept(command, result);
    } catch (error) {
      if (epoch !== generation.current) return;
      const uncertain =
        !(error instanceof NoticeError) ||
        error.status >= 500 ||
        error.status === 429 ||
        error.code === "uncertain_response";
      if (!uncertain && !retry) {
        clearNoticeCommand();
        setPending(null);
        setOpened(null);
        if (error instanceof NoticeError && error.code === "stale") {
          setPrepared(null);
          setNeedsRefresh(true);
          if (mode === "review" && view?.preparation_id) {
            setBlockedPreparation(view.preparation_id);
            const url = new URL(window.location.href);
            url.hash = new URLSearchParams({
              "stale-preparation": view.preparation_id,
            }).toString();
            window.history.replaceState(null, "", url);
          }
        }
      } else if (exact) setPending(exact);
      report(error);
    } finally {
      if (epoch === generation.current) setBusy(false);
    }
  }
  function accept(command: Command, result: Notice) {
    if (command.name === "prepare_operation") {
      setPrepared(result);
      setView((current) =>
        current
          ? { ...current, version: result.version, state: result.state }
          : current,
      );
      setMessage("Audience checked. Review this exact notice before submitting it.");
      return;
    }
    if (command.name === "open_notice") {
      if (typeof result.body === "string") {
        setOpened(result);
        setMessage("Notice opened.");
      } else {
        setOpened(null);
        setMessage(
          "The opening was already recorded. Open the current notice to view it.",
        );
      }
      return;
    }
    if (command.name === "confirm_receipt") {
      setView((current) =>
        current && current.revision_id === result.revision_id
          ? {
              ...current,
              own_receipt: {
                receipt_id: result.fact_id!,
                revision_id: result.revision_id!,
                statement,
                recorded_at: result.recorded_at!,
                status: "confirmed",
              },
            }
          : current,
      );
      setMessage("Receipt confirmed.");
      if (!opened) setMessage("Receipt confirmed for this version.");
      return;
    }
    setView((current) => ({ ...current, ...result }));
    setPrepared(null);
    setDirty(false);
    if (result.state === "withdrawn") {
      setOpened(null);
      setTitle("");
      setBody("");
    }
    if (command.name === "create_draft")
      window.history.replaceState(
        null,
        "",
        "/communications/" + result.notice_id + "/write",
      );
    const messages: Partial<Record<Command["name"], string>> = {
      create_draft: "Draft saved. Review the audience next.",
      revise_draft: "Draft saved. Prepare a fresh review.",
      submit_for_approval: "Submitted for a different authorized person to approve.",
      approve_operation:
        result.state === "withdrawn" ? "Notice withdrawn." : "Notice published.",
    };
    setMessage(messages[command.name] ?? "Request confirmed.");
  }
  async function reconcile() {
    if (!pending || !csrf) return;
    const epoch = ++generation.current;
    setBusy(true);
    try {
      const result = await noticeRequest<Outcome>(
        "/api/v1/communications/command-outcome",
        {
          notice_id: pending.body.notice_id ?? null,
          action: pending.name,
          idempotency_key: pending.body.idempotency_key,
        },
        csrf,
      );
      if (epoch !== generation.current) return;
      if (result.status === "committed" && result.result) {
        clearNoticeCommand();
        setPending(null);
        setResumeText(false);
        setCheckedAbsent(false);
        setOpened(null);
        setPrepared(null);
        if (pending.name === "create_draft")
          window.history.replaceState(
            null,
            "",
            "/communications/" + result.result.notice_id + "/write",
          );
        const loaded = await load(result.result.notice_id);
        if (loaded)
          setMessage(
            "The original request was recorded. The current task has been reloaded.",
          );
      } else {
        setCheckedAbsent(true);
        setMessage(
          pending.metadataOnly
            ? "No recorded result was found. Re-enter the original text to retry with the same request identity."
            : "No recorded result was found. You may retry this same request.",
        );
      }
    } catch (error) {
      if (epoch === generation.current) report(error);
    } finally {
      if (epoch === generation.current) setBusy(false);
    }
  }
  function retryFromFields() {
    if (!pending || !checkedAbsent || !resumeText || !validateContent()) return;
    const original: Command = {
      name: pending.name,
      body: {
        ...pending.body,
        title,
        body,
        ...(pending.name === "prepare_operation"
          ? { reason: pending.body.operation === "publish" ? "" : reason }
          : {}),
      },
    };
    void execute(original, true);
  }
  function save(event: FormEvent) {
    event.preventDefault();
    if (pending) {
      retryFromFields();
      return;
    }
    if (!validateContent()) return;
    void execute({
      name: id ? "revise_draft" : "create_draft",
      body: {
        ...references(),
        ...(id ? { notice_id: id, expected_version: view?.version } : {}),
        title,
        body,
        receipt_required: receipt,
      },
    });
  }
  function prepare() {
    if (pending) {
      retryFromFields();
      return;
    }
    if (!id || !validateContent()) return;
    void execute({
      name: "prepare_operation",
      body: {
        ...references(),
        notice_id: id,
        expected_version: view?.version,
        operation,
        title,
        body,
        reason: operation === "publish" ? "" : reason,
      },
    });
  }
  function submit() {
    if (!id || !prepared?.preparation_id) return;
    void execute({
      name: "submit_for_approval",
      body: {
        ...references(),
        notice_id: id,
        expected_version: view?.version,
        preparation_id: prepared.preparation_id,
      },
    });
  }
  function approve() {
    if (!id || !view?.preparation_id) return;
    void execute({
      name: "approve_operation",
      body: {
        ...references(),
        notice_id: id,
        expected_version: view.version,
        preparation_id: view.preparation_id,
      },
    });
  }
  function engage(name: "open_notice" | "confirm_receipt") {
    if (!id || !view?.revision_id) return;
    void execute({
      name,
      body: { ...references(), notice_id: id, revision_id: view.revision_id },
    });
  }

  const expiryKey = `${view?.preparation_id ?? ""}/${view?.expires_at ?? ""}`;
  const [expiry, setExpiry] = useState<{ key: string; expired: boolean } | null>(null);
  useEffect(() => {
    const due = Date.parse((view?.expires_at ?? "") + "Z");
    const initial = window.setTimeout(
      () =>
        setExpiry({
          key: expiryKey,
          expired: !Number.isFinite(due) || Date.now() >= due,
        }),
      0,
    );
    const boundary = Number.isFinite(due)
      ? window.setTimeout(
          () => setExpiry({ key: expiryKey, expired: true }),
          Math.max(0, due - Date.now()),
        )
      : undefined;
    return () => {
      window.clearTimeout(initial);
      if (boundary !== undefined) window.clearTimeout(boundary);
    };
  }, [expiryKey, view?.expires_at]);

  const disabled = busy || !!pending || needsRefresh;
  const editingDisabled = busy || (!!pending && !resumeText) || needsRefresh;
  const expired = !!view?.expires_at && (expiry?.key !== expiryKey || expiry.expired);
  const label =
    mode === "write"
      ? "Write notice"
      : mode === "review"
        ? "Review for approval"
        : mode === "metrics"
          ? "Notice results"
          : "Staff notice";

  return (
    <main className="c-staff c-communications">
      <CommunicationsProofPersonas disabled={busy || !!pending} />
      <PageHeading
        eyebrow="Local fictional proof"
        title={label}
        description="Staff notices · Closed comments and reactions"
      />
      <p className="c-staff__identity">
        {view?.institution ??
          institution ??
          (busy
            ? "Checking the selected institution"
            : "Institution access unavailable")}{" "}
        · Restricted
      </p>
      <nav aria-label="Notice tasks" className="c-staff__actions">
        {busy || pending ? (
          <ActionButton disabled variant="quiet">
            New notice
          </ActionButton>
        ) : (
          <ActionLink href="/communications" variant="quiet" reloadDocument>
            New notice
          </ActionLink>
        )}
        {id && !busy && !pending && (
          <>
            <ActionLink href={"/communications/" + id + "/write"} variant="quiet">
              Write
            </ActionLink>
            <ActionLink href={"/communications/" + id + "/review"} variant="quiet">
              Approval
            </ActionLink>
            <ActionLink href={"/communications/" + id} variant="quiet">
              Recipient
            </ActionLink>
          </>
        )}
      </nav>
      <div
        ref={feedback}
        tabIndex={-1}
        className="c-staff__message"
        role={message ? "status" : undefined}
        aria-live="polite"
      >
        {busy ? "Checking current notice…" : message || "Choose your next action."}
      </div>
      {pending && !busy && (
        <section aria-label="Uncertain request">
          <p>The result is uncertain. Keep this request until it has been checked.</p>
          <p>Finish checking this request before changing tasks or personas.</p>
          <div className="c-staff__actions">
            <ActionButton onClick={() => void reconcile()} disabled={!csrf}>
              Check this request
            </ActionButton>
            {checkedAbsent && !pending.metadataOnly && (
              <ActionButton
                onClick={() => void execute(pending, true)}
                disabled={!csrf}
                variant="secondary"
              >
                Retry same request
              </ActionButton>
            )}
            {checkedAbsent && pending.metadataOnly && (
              <ActionButton
                onClick={() => {
                  setResumeText(true);
                  setReceipt(pending.body.receipt_required === true);
                  const op = pending.body.operation;
                  if (op === "publish" || op === "correct" || op === "withdraw")
                    setOperation(op);
                }}
                disabled={!csrf}
                variant="secondary"
              >
                Re-enter original text
              </ActionButton>
            )}
          </div>
        </section>
      )}
      {csrf && !busy && message && !pending && (
        <ActionButton onClick={() => void load()} variant="secondary">
          Reload current state
        </ActionButton>
      )}
      {!csrf && !busy && (
        <ActionButton onClick={() => void load()}>Check access again</ActionButton>
      )}
      {csrf && view && (
        <p>
          Version {view.number ?? 0} ·{" "}
          {withdrawn
            ? "Withdrawn"
            : view.state === "pending"
              ? "Awaiting approval"
              : view.state === "published"
                ? "Published"
                : "Draft"}
        </p>
      )}
      {csrf && withdrawn && (
        <Panel
          eyebrow="Staff communications"
          title="Notice withdrawn"
          titleId="notice-withdrawn"
        >
          <div className="c-communications__content">
            <p>
              This notice is no longer available. New receipt confirmations are closed.
            </p>
          </div>
        </Panel>
      )}
      {csrf && !withdrawn && mode === "write" && (
        <Panel
          eyebrow="Staff communications"
          title={view?.number ? "Prepare a correction" : "Notice content"}
          titleId="notice-write"
        >
          {view?.number ? (
            <div className="c-staff__actions">
              <ActionButton
                variant={operation === "correct" ? "primary" : "secondary"}
                onClick={() => {
                  setOperation("correct");
                  setPrepared(null);
                }}
                disabled={disabled}
              >
                Prepare a correction
              </ActionButton>
              <ActionButton
                variant={operation === "withdraw" ? "primary" : "secondary"}
                onClick={() => {
                  setOperation("withdraw");
                  setPrepared(null);
                }}
                disabled={disabled}
              >
                Request withdrawal
              </ActionButton>
            </div>
          ) : null}
          <form className="c-staff__form" onSubmit={save} noValidate>
            <label htmlFor="notice-title">
              Title
              <input
                id="notice-title"
                value={title}
                onChange={(e) => {
                  setTitle(e.target.value);
                  changed("title");
                }}
                aria-invalid={!!fieldErrors.title}
                aria-describedby={fieldErrors.title ? "notice-title-error" : undefined}
                disabled={editingDisabled}
              />
            </label>
            {fieldErrors.title && <p id="notice-title-error">{fieldErrors.title}</p>}
            <label htmlFor="notice-body">
              Body
              <textarea
                id="notice-body"
                rows={7}
                value={body}
                onChange={(e) => {
                  setBody(e.target.value);
                  changed("body");
                }}
                aria-invalid={!!fieldErrors.body}
                aria-describedby={fieldErrors.body ? "notice-body-error" : undefined}
                disabled={editingDisabled}
              />
            </label>
            {fieldErrors.body && <p id="notice-body-error">{fieldErrors.body}</p>}
            {!view?.number ? (
              <label className="c-staff__check">
                <input
                  type="checkbox"
                  checked={receipt}
                  onChange={(e) => {
                    setReceipt(e.target.checked);
                    changed();
                  }}
                  disabled={busy || !!pending}
                />
                Request receipt confirmation
              </label>
            ) : (
              <>
                <p>
                  Receipt confirmation{" "}
                  {receipt ? "required for each version" : "not requested"}; this choice
                  stays fixed.
                </p>
                <label htmlFor="notice-reason">
                  {operation === "withdraw" ? "Withdrawal reason" : "Correction reason"}
                  <input
                    id="notice-reason"
                    value={reason}
                    onChange={(e) => {
                      setReason(e.target.value);
                      setPrepared(null);
                    }}
                    aria-invalid={!!fieldErrors.reason}
                    aria-describedby={
                      fieldErrors.reason ? "notice-reason-error" : undefined
                    }
                    disabled={editingDisabled}
                  />
                </label>
                {fieldErrors.reason && (
                  <p id="notice-reason-error">{fieldErrors.reason}</p>
                )}
              </>
            )}
            <div className="c-staff__actions">
              {!view?.number && (!pending || pending.name !== "prepare_operation") && (
                <ActionButton type="submit" disabled={editingDisabled}>
                  {resumeText ? "Retry original request" : "Save draft"}
                </ActionButton>
              )}
              {id && (!pending || pending.name === "prepare_operation") && (
                <ActionButton
                  onClick={prepare}
                  disabled={editingDisabled || (!view?.number && dirty && !resumeText)}
                  variant="secondary"
                >
                  {resumeText
                    ? "Retry original request"
                    : operation === "withdraw"
                      ? "Review withdrawal"
                      : "Review audience"}
                </ActionButton>
              )}
            </div>
          </form>
        </Panel>
      )}
      {csrf && prepared && (
        <Panel
          eyebrow="Staff communications"
          title={operation === "withdraw" ? "Review withdrawal" : "Review notice"}
          titleId="notice-prepared"
        >
          <div className="c-communications__content">
            <h3>{title}</h3>
            <p className="c-communications__body">{body}</p>
            {operation !== "publish" && <p>Reason: {reason}</p>}
            <Counts view={prepared} />
            <p>Receipt confirmation {receipt ? "requested" : "not requested"}.</p>
            <p>
              Checked until {noticeTime(prepared.expires_at)}. A different authorized
              person must approve this exact operation.
            </p>
            {operation === "withdraw" && (
              <p>Approval will hide the notice and stop new receipt confirmations.</p>
            )}
            <ActionButton onClick={submit} disabled={disabled}>
              Submit for approval
            </ActionButton>
          </div>
        </Panel>
      )}
      {csrf && !pending && mode === "write" && view?.state === "pending" && (
        <Panel
          eyebrow="Staff communications"
          title="Awaiting approval"
          titleId="notice-pending"
        >
          <div className="c-communications__content">
            <p>
              A different authorized person must review and approve the submitted
              operation.
            </p>
            <ActionLink href={`/communications/${id}/review`}>
              Open approval task
            </ActionLink>
          </div>
        </Panel>
      )}
      {csrf &&
        !withdrawn &&
        mode === "review" &&
        view &&
        typeof view.body === "string" && (
          <Panel
            eyebrow="Staff communications"
            title={
              view.state === "pending"
                ? "Exact operation for approval"
                : "Current published notice"
            }
            titleId="notice-review"
          >
            <div className="c-communications__content">
              <h3>{view.title}</h3>
              <p className="c-communications__body">{view.body}</p>
              {view.reason && <p>Reason: {view.reason}</p>}
              <Counts view={view} published={view.state !== "pending"} />
              <p>
                Receipt confirmation{" "}
                {view.receipt_required ? "requested for each version" : "not requested"}
                .
              </p>
              {view.expires_at && (
                <p>
                  Review expires {noticeTime(view.expires_at)}. Any change requires
                  fresh preparation and approval.
                </p>
              )}
              {view.operation === "withdraw" && (
                <p>Approval will hide the notice and stop new receipt confirmations.</p>
              )}
              {view.state === "pending" && (
                <ActionButton
                  onClick={approve}
                  disabled={
                    disabled ||
                    view.state !== "pending" ||
                    expired ||
                    view.preparation_id === blockedPreparation
                  }
                >
                  {view.operation === "withdraw"
                    ? "Approve withdrawal"
                    : view.operation === "correct"
                      ? "Approve and publish correction"
                      : "Approve and publish"}
                </ActionButton>
              )}
              {view.revision_id && !pending && (
                <ActionLink
                  href={`/communications/${id}/metrics?revision=${view.revision_id}`}
                  variant="secondary"
                >
                  View results
                </ActionLink>
              )}
            </div>
          </Panel>
        )}
      {csrf && !withdrawn && mode === "notice" && view && (
        <Panel
          eyebrow="Staff communications"
          title="Staff notice"
          titleId="notice-recipient"
        >
          <div className="c-communications__content">
            <p>Openings and receipt confirmations are recorded.</p>
            {!opened ? (
              <ActionButton onClick={() => engage("open_notice")} disabled={disabled}>
                Open notice
              </ActionButton>
            ) : (
              <article>
                <p>
                  From staff communications · {view.institution} · Version{" "}
                  {opened.number} · {noticeTime(opened.published_at)}
                </p>
                <h3>{opened.title}</h3>
                <p className="c-communications__body">{opened.body}</p>
                {opened.reason && <p>Correction: {opened.reason}</p>}
              </article>
            )}
            {view.receipt_required ? (
              opened &&
              opened.revision_id === view.revision_id && (
                <>
                  <p>{statement}</p>
                  {view.own_receipt ? (
                    <p role="status">Receipt confirmed for this version.</p>
                  ) : (
                    <ActionButton
                      onClick={() => engage("confirm_receipt")}
                      disabled={disabled}
                    >
                      Confirm receipt
                    </ActionButton>
                  )}
                </>
              )
            ) : (
              <p>No receipt confirmation requested.</p>
            )}
          </div>
        </Panel>
      )}
      {csrf && mode === "metrics" && view && (
        <Panel
          eyebrow="Staff communications"
          title="Exact version results"
          titleId="notice-metrics"
        >
          <div className="c-communications__content">
            <Counts view={view} published />
            <p>
              Opened {view.opened ?? 0} of {view.eligibility?.audience ?? 0}
            </p>
            {view.receipt_required && (
              <p>
                Receipt confirmed {view.receipt_confirmed ?? 0} of{" "}
                {view.eligibility?.audience ?? 0}
              </p>
            )}
            <p>
              Published {noticeTime(view.published_at)} · Counts as of{" "}
              {noticeTime(view.metrics_as_of)}
            </p>
          </div>
        </Panel>
      )}
    </main>
  );
}
function Counts({ view, published = false }: { view: Notice; published?: boolean }) {
  const counts = view.eligibility;
  if (!counts) return null;
  return (
    <dl className="c-communications__counts">
      <dt>Audience</dt>
      <dd>{counts.audience}</dd>
      <dt>
        {published
          ? "Eligible when this version was published"
          : "Eligible in this preparation"}
      </dt>
      <dd>{counts.eligible}</dd>
      <dt>
        {published
          ? "No eligible account at publication"
          : "No eligible account in this preparation"}
      </dt>
      <dd>{counts.no_eligible_account}</dd>
      <dt>
        {published
          ? "No current access at publication"
          : "No current access in this preparation"}
      </dt>
      <dd>{counts.no_current_access}</dd>
    </dl>
  );
}

function noticeTime(value?: string) {
  if (!value) return "unavailable";
  const instant = new Date(value + "Z");
  return Number.isNaN(instant.valueOf())
    ? "unavailable"
    : new Intl.DateTimeFormat("en-GB", {
        dateStyle: "medium",
        timeStyle: "short",
        timeZone: "UTC",
      }).format(instant) + " UTC";
}
