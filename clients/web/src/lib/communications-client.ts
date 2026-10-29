import type { components, paths } from "../generated/public/communications-schema";
export type Notice = components["schemas"]["NoticeView"];
export type Outcome = components["schemas"]["CommandOutcome"];
export type CommandName =
  | "create_draft"
  | "revise_draft"
  | "prepare_operation"
  | "submit_for_approval"
  | "approve_operation"
  | "open_notice"
  | "confirm_receipt";
export type Command = { name: CommandName; body: Record<string, unknown> };
export class NoticeError extends Error {
  constructor(
    readonly status: number,
    readonly code?: string,
  ) {
    super("Notice action was not confirmed");
  }
}
export async function noticeRequest<T>(
  path: keyof paths,
  body?: object,
  csrf?: string,
  query?: Record<string, string>,
): Promise<T> {
  const suffix = query ? "?" + new URLSearchParams(query).toString() : "";
  const response = await fetch(path + suffix, {
    method: body ? "POST" : "GET",
    credentials: "same-origin",
    cache: "no-store",
    headers: {
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {}),
      ...(csrf ? { "X-CSRF-Token": csrf } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const payload = (await response.json()) as {
    data?: T;
    errors?: { code?: string }[];
  };
  if (!response.ok) throw new NoticeError(response.status, payload.errors?.[0]?.code);
  const data = payload.data as Record<string, unknown> | undefined;
  const valid =
    data &&
    typeof data === "object" &&
    !Array.isArray(data) &&
    (path === "/api/v1/communications/command-outcome"
      ? data.status === "not_recorded" ||
        (data.status === "committed" &&
          validCommandResult(data.result, (body as Record<string, unknown>)?.action))
      : path === "/api/v1/communications/workspace"
        ? typeof data.institution === "string"
        : body
          ? validCommandResult(
              data,
              path.slice(path.lastIndexOf("/") + 1).replaceAll("-", "_"),
              body as Record<string, unknown>,
            )
          : uuid(data.notice_id));
  if (!valid) throw new NoticeError(response.status, "uncertain_response");
  return payload.data as T;
}
const uuid = (value: unknown) =>
  typeof value === "string" &&
  /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(value);
function validCommandResult(
  value: unknown,
  action: unknown,
  original?: Record<string, unknown>,
): boolean {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const result = value as Record<string, unknown>;
  if (
    !uuid(result.notice_id) ||
    (original?.notice_id && result.notice_id !== original.notice_id)
  )
    return false;
  if (action === "open_notice" || action === "confirm_receipt")
    return (
      uuid(result.revision_id) &&
      uuid(result.fact_id) &&
      typeof result.recorded_at === "string" &&
      Number.isFinite(Date.parse(result.recorded_at)) &&
      result.kind === (action === "open_notice" ? "opening" : "receipt") &&
      (!original?.revision_id || result.revision_id === original.revision_id)
    );
  if (!Number.isInteger(result.version) || Number(result.version) < 1) return false;
  if (action === "prepare_operation")
    return (
      uuid(result.preparation_id) &&
      typeof result.expires_at === "string" &&
      Number.isFinite(Date.parse(result.expires_at))
    );
  return (
    [
      "create_draft",
      "revise_draft",
      "submit_for_approval",
      "approve_operation",
    ].includes(String(action)) &&
    ["draft", "pending", "published", "withdrawn"].includes(String(result.state))
  );
}
export const commandPath = (name: CommandName) =>
  ("/api/v1/communications/" + name.replaceAll("_", "-")) as keyof paths;
export const references = () => ({
  idempotency_key: crypto.randomUUID(),
  causation_id: crypto.randomUUID(),
});
export function noticeMessage(error: unknown, recipient = false) {
  if (error instanceof NoticeError) {
    if (error.code === "stale")
      return recipient
        ? "This notice changed. Reload the current version before opening or confirming receipt."
        : "This preparation changed or expired. Refresh it and submit it for a new approval.";
    if (error.code === "scope_limit")
      return "This local proof allows five notices, two versions per notice and 25 staff. The limit has been reached.";
    if (error.status === 401 || error.status === 403)
      return "Access to this action could not be confirmed. Use an authorized account.";
    if (error.code === "idempotency_conflict")
      return "This request has changed. Reload the current notice before continuing.";
    if (error.status === 429)
      return "The service is busy. Check this request before retrying.";
    if (error.status === 400) return "Check the notice fields before continuing.";
    if (error.status === 409)
      return "This action is unavailable for the current notice. Reload its latest state.";
  }
  return "The result is uncertain. Check this request before trying again.";
}
