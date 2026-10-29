import type { Command, CommandName } from "./communications-client";
export type PendingNoticeCommand = Command & { digest: string; metadataOnly?: boolean };
const fields: Record<CommandName, readonly string[]> = {
  create_draft: ["idempotency_key", "causation_id", "receipt_required"],
  revise_draft: [
    "idempotency_key",
    "causation_id",
    "notice_id",
    "expected_version",
    "receipt_required",
  ],
  prepare_operation: [
    "idempotency_key",
    "causation_id",
    "notice_id",
    "expected_version",
    "operation",
  ],
  submit_for_approval: [
    "idempotency_key",
    "causation_id",
    "notice_id",
    "expected_version",
    "preparation_id",
  ],
  approve_operation: [
    "idempotency_key",
    "causation_id",
    "notice_id",
    "expected_version",
    "preparation_id",
  ],
  open_notice: ["idempotency_key", "causation_id", "notice_id", "revision_id"],
  confirm_receipt: ["idempotency_key", "causation_id", "notice_id", "revision_id"],
};
const contentCommands = new Set<CommandName>([
  "create_draft",
  "revise_draft",
  "prepare_operation",
]);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const fragmentKey = "notice-request";
export async function noticeCommandDigest(command: Command) {
  const ordered = Object.fromEntries(
    Object.entries(command.body).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)),
  );
  const data = new TextEncoder().encode(
    JSON.stringify({ name: command.name, body: ordered }),
  );
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest), (v) =>
    v.toString(16).padStart(2, "0"),
  ).join("");
}
export function retainNoticeCommand(command: PendingNoticeCommand) {
  const body = Object.fromEntries(
    fields[command.name].map((key) => [key, command.body[key]]),
  );
  const url = new URL(window.location.href);
  url.hash = new URLSearchParams({
    [fragmentKey]: JSON.stringify({ name: command.name, body, digest: command.digest }),
  }).toString();
  window.history.replaceState(null, "", url);
}
export function clearNoticeCommand() {
  const url = new URL(window.location.href);
  if (!new URLSearchParams(url.hash.slice(1)).has(fragmentKey)) return;
  url.hash = "";
  window.history.replaceState(null, "", url);
}
export function restoreNoticeCommand(): PendingNoticeCommand | null {
  try {
    const encoded = new URLSearchParams(window.location.hash.slice(1)).get(fragmentKey);
    if (!encoded || encoded.length > 2500) return null;
    const value: unknown = JSON.parse(encoded);
    if (!value || typeof value !== "object" || Array.isArray(value)) return null;
    const { name, body, digest } = value as Record<string, unknown>;
    if (
      typeof name !== "string" ||
      !Object.hasOwn(fields, name) ||
      typeof digest !== "string" ||
      !/^[0-9a-f]{64}$/.test(digest) ||
      !body ||
      typeof body !== "object" ||
      Array.isArray(body) ||
      Object.keys(value).sort().join() !== "body,digest,name"
    )
      return null;
    const commandName = name as CommandName;
    const record = body as Record<string, unknown>;
    if (Object.keys(record).sort().join() !== [...fields[commandName]].sort().join())
      return null;
    for (const [key, item] of Object.entries(record)) {
      if (key === "expected_version") {
        if (typeof item !== "number" || !Number.isSafeInteger(item) || item < 1)
          return null;
      } else if (key === "receipt_required") {
        if (typeof item !== "boolean") return null;
      } else if (key === "operation") {
        if (!["publish", "correct", "withdraw"].includes(String(item))) return null;
      } else if (typeof item !== "string" || !uuid.test(item)) return null;
    }
    return {
      name: commandName,
      body: record,
      digest,
      metadataOnly: contentCommands.has(commandName),
    };
  } catch {
    return null;
  }
}
