import "server-only";

import createClient from "openapi-fetch";

import type { paths } from "../generated/ui1/schema";
import type { AssignmentOptionsData, CoreBridgeResult } from "../ports/core-bridge";

const assignmentOptionsPath = "/api/v1/authority/assignment-options" as const;
const minimumTokenBytes = 32;

function localBaseUrl(value: string | undefined): string | undefined {
  if (!value) return undefined;

  try {
    const url = new URL(value);
    const loopback =
      url.hostname === "127.0.0.1" ||
      url.hostname === "localhost" ||
      url.hostname === "[::1]";

    if (url.protocol !== "http:" || !loopback || url.username || url.password) {
      return undefined;
    }

    return url.origin;
  } catch {
    return undefined;
  }
}

function decodeOptions(value: unknown): AssignmentOptionsData | undefined {
  if (!value || typeof value !== "object") return undefined;

  const candidate = value as Record<string, unknown>;
  if (
    candidate.connection !== "local_core" ||
    candidate.contract_version !== 1 ||
    !Array.isArray(candidate.memberships) ||
    !Array.isArray(candidate.roles)
  ) {
    return undefined;
  }

  const decodeList = (items: unknown[]) =>
    items.every(
      (item) =>
        !!item &&
        typeof item === "object" &&
        typeof (item as Record<string, unknown>).id === "string" &&
        typeof (item as Record<string, unknown>).label === "string",
    )
      ? items.map((item) => {
          const option = item as Record<string, string>;
          return { id: option.id, label: option.label };
        })
      : undefined;

  const memberships = decodeList(candidate.memberships);
  const roles = decodeList(candidate.roles);
  if (!memberships || !roles) return undefined;

  return {
    connection: "local_core",
    contract_version: 1,
    memberships,
    roles,
  };
}

export async function getAssignmentOptions(): Promise<CoreBridgeResult> {
  if (process.env.CHIMWEMWE_UI1_LOCAL !== "true") {
    return { state: "disabled" };
  }

  const baseUrl = localBaseUrl(process.env.CHIMWEMWE_UI1_API_URL);
  const token = process.env.CHIMWEMWE_UI1_BRIDGE_TOKEN;

  if (!baseUrl || !token || Buffer.byteLength(token) < minimumTokenBytes) {
    return { state: "disabled" };
  }

  const client = createClient<paths>({
    baseUrl,
    cache: "no-store",
    headers: { authorization: `Bearer ${token}` },
  });

  try {
    const result = await client.GET(assignmentOptionsPath);

    const data = result.data ? decodeOptions(result.data.data) : undefined;
    if (result.response.status === 200 && data) {
      return { state: "ready", data };
    }

    if (result.response.status === 401 || result.response.status === 403) {
      return { state: "denied" };
    }

    if (result.response.status === 503) return { state: "retryable" };

    return {
      state: "unexpected",
      reference: result.response.headers.get("x-request-id") ?? undefined,
    };
  } catch {
    return { state: "unavailable" };
  }
}
