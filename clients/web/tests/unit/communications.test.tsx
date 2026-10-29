import { webcrypto } from "node:crypto";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CommunicationsWorkspace } from "../../src/components/communications-workspace";
const id = "00000000-0000-4000-8000-000000000001";
const revision = "00000000-0000-4000-8000-000000000002";
const base = {
  notice_id: id,
  version: 3,
  number: 1,
  state: "published",
  institution: "Fictional School",
  revision_id: revision,
  receipt_required: true,
  own_receipt: null,
  classification: "Restricted",
};
function server(receipt = true) {
  let confirmed = false;
  const calls: { path: string; body?: Record<string, unknown> }[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (path: string, init?: RequestInit) => {
      const input = init?.body ? JSON.parse(init.body as string) : undefined;
      calls.push({ path, body: input });
      let data: unknown;
      if (path === "/api/v1/session") data = { csrf_token: "test-csrf" };
      else if (path.startsWith("/api/v1/communications/status"))
        data = {
          ...base,
          receipt_required: receipt,
          own_receipt: confirmed
            ? {
                receipt_id: id,
                revision_id: revision,
                statement: "I acknowledge receipt of this notice.",
                recorded_at: "2026-10-27T00:00:00",
                status: "confirmed",
              }
            : null,
        };
      else if (path.endsWith("/open-notice"))
        data = {
          ...base,
          fact_id: id,
          kind: "opening",
          recorded_at: "2026-10-26T09:00:00",
          title: "<script>Plain title</script>",
          body: "Plain body",
          published_at: "2026-10-26T09:00:00",
        };
      else if (path.endsWith("/workspace"))
        data = { institution: "Fictional School", classification: "Restricted" };
      else if (path.endsWith("/confirm-receipt")) {
        confirmed = true;
        data = {
          notice_id: id,
          revision_id: revision,
          fact_id: id,
          recorded_at: "2026-10-26T09:01:00",
          kind: "receipt",
        };
      } else throw new Error("Unexpected request");
      return new Response(JSON.stringify({ data }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }),
  );
  return calls;
}
async function ensureOpened() {
  if (screen.queryByText("Plain body")) return;
  await userEvent.click(await screen.findByRole("button", { name: "Open notice" }));
  await screen.findByText("Plain body");
}
beforeEach(() => {
  vi.stubGlobal("crypto", webcrypto);
  window.history.replaceState(null, "", "/communications");
});
afterEach(() => {
  window.history.replaceState(null, "", "/communications");
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});
describe("bounded staff notices", () => {
  it("clears displayed content after denied outcome recovery", async () => {
    server();
    const original = globalThis.fetch;
    vi.stubGlobal(
      "fetch",
      vi.fn(async (path: string, init?: RequestInit) => {
        if (path.endsWith("/confirm-receipt")) {
          await original(path, init);
          throw new TypeError("Lost");
        }
        if (path.endsWith("/command-outcome"))
          return new Response(JSON.stringify({ errors: [{ code: "forbidden" }] }), {
            status: 403,
          });
        return original(path, init);
      }),
    );
    render(<CommunicationsWorkspace noticeId={id} mode="notice" />);
    await userEvent.click(await screen.findByRole("button", { name: "Open notice" }));
    expect(await screen.findByText("Plain body")).toBeVisible();
    await ensureOpened();
    await userEvent.click(screen.getByRole("button", { name: "Confirm receipt" }));
    await userEvent.click(
      await screen.findByRole("button", { name: "Check this request" }),
    );
    expect(
      await screen.findByText(
        "Access to this action could not be confirmed. Use an authorized account.",
      ),
    ).toBeVisible();
    expect(screen.queryByText("Plain body")).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Confirm receipt" }),
    ).not.toBeInTheDocument();
  });

  it.each(["confirmation", "committed outcome"])(
    "keeps malformed %s uncertain",
    async (fault) => {
      server();
      const original = globalThis.fetch;
      vi.stubGlobal(
        "fetch",
        vi.fn(async (path: string, init?: RequestInit) => {
          if (path.endsWith("/confirm-receipt")) {
            if (fault === "confirmation")
              return new Response(JSON.stringify({ data: { notice_id: id } }), {
                status: 200,
              });
            throw new TypeError("Lost");
          }
          if (path.endsWith("/command-outcome"))
            return new Response(JSON.stringify({ data: { status: "committed" } }), {
              status: 200,
            });
          return original(path, init);
        }),
      );
      render(<CommunicationsWorkspace noticeId={id} mode="notice" />);
      await ensureOpened();
      await userEvent.click(
        await screen.findByRole("button", { name: "Confirm receipt" }),
      );
      await userEvent.click(
        await screen.findByRole("button", { name: "Check this request" }),
      );
      expect(
        await screen.findByRole("button", { name: "Check this request" }),
      ).toBeEnabled();
      expect(
        screen.queryByRole("button", { name: "Retry same request" }),
      ).not.toBeInTheDocument();
      expect(
        screen.queryByText("Receipt confirmed for this version."),
      ).not.toBeInTheDocument();
      expect(window.location.hash).toContain("notice-request");
    },
  );
  it("denied retry clears content and retains the unresolved original identity", async () => {
    server();
    const original = globalThis.fetch;
    let attempts = 0;
    vi.stubGlobal(
      "fetch",
      vi.fn(async (path: string, init?: RequestInit) => {
        if (path.endsWith("/confirm-receipt")) {
          attempts++;
          if (attempts === 1) throw new TypeError("Lost");
          return new Response(JSON.stringify({ errors: [{ code: "forbidden" }] }), {
            status: 403,
          });
        }
        if (path.endsWith("/command-outcome"))
          return new Response(JSON.stringify({ data: { status: "not_recorded" } }), {
            status: 200,
          });
        return original(path, init);
      }),
    );
    render(<CommunicationsWorkspace noticeId={id} mode="notice" />);
    await userEvent.click(await screen.findByRole("button", { name: "Open notice" }));
    await screen.findByText("Plain body");
    await ensureOpened();
    await userEvent.click(screen.getByRole("button", { name: "Confirm receipt" }));
    await userEvent.click(
      await screen.findByRole("button", { name: "Check this request" }),
    );
    const identity = window.location.hash;
    await userEvent.click(
      await screen.findByRole("button", { name: "Retry same request" }),
    );
    await screen.findByText(
      "Access to this action could not be confirmed. Use an authorized account.",
    );
    expect(screen.queryByText("Plain body")).not.toBeInTheDocument();
    expect(window.location.hash).toBe(identity);
    expect(screen.getByRole("button", { name: "New notice" })).toBeDisabled();
  });
  it.each([200, 429])(
    "keeps command identity and recovery controls for malformed success or capacity refusal (%s)",
    async (status) => {
      server();
      const original = globalThis.fetch;
      vi.stubGlobal(
        "fetch",
        vi.fn(async (path: string, init?: RequestInit) => {
          if (path.endsWith("/confirm-receipt"))
            return new Response(
              JSON.stringify(
                status === 200 ? {} : { errors: [{ code: "rate_limited" }] },
              ),
              { status },
            );
          return original(path, init);
        }),
      );
      render(<CommunicationsWorkspace noticeId={id} mode="notice" />);
      await ensureOpened();
      await userEvent.click(
        await screen.findByRole("button", { name: "Confirm receipt" }),
      );
      expect(
        await screen.findByRole("button", { name: "Check this request" }),
      ).toBeEnabled();
      expect(
        screen.queryByRole("button", { name: "Retry same request" }),
      ).not.toBeInTheDocument();
      expect(screen.getByRole("button", { name: "New notice" })).toBeDisabled();
      expect(window.location.hash).toContain("notice-request");
      await userEvent.click(
        screen.getByText("Fictional proof personas", { exact: true }),
      );
      expect(
        screen.getByRole("button", { name: "Use fictional author" }),
      ).toBeDisabled();
    },
  );

  it("restores an interrupted receipt after reload and retries the exact key only after lookup", async () => {
    server();
    const original = globalThis.fetch;
    const posts: Record<string, unknown>[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (path: string, init?: RequestInit) => {
        if (path.endsWith("/confirm-receipt")) {
          posts.push(JSON.parse(init!.body as string));
          if (posts.length === 1) throw new TypeError("Lost before entry");
        }
        if (path.endsWith("/command-outcome"))
          return new Response(JSON.stringify({ data: { status: "not_recorded" } }), {
            status: 200,
          });
        return original(path, init);
      }),
    );
    const first = render(<CommunicationsWorkspace noticeId={id} mode="notice" />);
    await ensureOpened();
    await userEvent.click(
      await screen.findByRole("button", { name: "Confirm receipt" }),
    );
    await screen.findByRole("button", { name: "Check this request" });
    first.unmount();
    render(<CommunicationsWorkspace noticeId={id} mode="notice" />);
    expect(
      await screen.findByRole("button", { name: "Check this request" }),
    ).toBeVisible();
    expect(posts).toHaveLength(1);
    expect(
      screen.queryByRole("button", { name: "Retry same request" }),
    ).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Check this request" }));
    await userEvent.click(
      await screen.findByRole("button", { name: "Retry same request" }),
    );
    expect(
      await screen.findByText("Receipt confirmed for this version."),
    ).toBeVisible();
    expect(posts).toHaveLength(2);
    expect(posts[1]).toEqual(posts[0]);
    expect(window.location.hash).toBe("");
  });

  it("restores lost create without storing text and requires original-text same-key retry", async () => {
    server();
    const original = globalThis.fetch;
    const posts: Record<string, unknown>[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (path: string, init?: RequestInit) => {
        if (path.endsWith("/create-draft")) {
          posts.push(JSON.parse(init!.body as string));
          if (posts.length === 1) throw new TypeError("Lost");
          return new Response(
            JSON.stringify({
              data: {
                notice_id: id,
                version: 1,
                state: "draft",
                institution: "Fictional School",
              },
            }),
            { status: 200 },
          );
        }
        if (path.endsWith("/command-outcome"))
          return new Response(JSON.stringify({ data: { status: "not_recorded" } }), {
            status: 200,
          });
        return original(path, init);
      }),
    );
    const first = render(<CommunicationsWorkspace mode="write" />);
    await userEvent.type(
      await screen.findByLabelText("Title", { exact: true }),
      "Original fictional title",
    );
    await userEvent.type(
      screen.getByLabelText("Body", { exact: true }),
      "Original fictional body",
    );
    await userEvent.click(screen.getByRole("button", { name: "Save draft" }));
    await screen.findByRole("button", { name: "Check this request" });
    expect(decodeURIComponent(window.location.hash)).not.toContain(
      "Original fictional",
    );
    first.unmount();
    render(<CommunicationsWorkspace mode="write" />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Check this request" }),
    );
    await userEvent.click(
      await screen.findByRole("button", { name: "Re-enter original text" }),
    );
    await userEvent.type(
      screen.getByLabelText("Title", { exact: true }),
      "Changed title",
    );
    await userEvent.type(
      screen.getByLabelText("Body", { exact: true }),
      "Original fictional body",
    );
    await userEvent.click(
      screen.getByRole("button", { name: "Retry original request" }),
    );
    expect(
      await screen.findByText(
        "This text does not match the original request. Re-enter the original text to retry safely.",
      ),
    ).toBeVisible();
    expect(posts).toHaveLength(1);
    await userEvent.clear(screen.getByLabelText("Title", { exact: true }));
    await userEvent.type(
      screen.getByLabelText("Title", { exact: true }),
      "Original fictional title",
    );
    await userEvent.click(
      screen.getByRole("button", { name: "Retry original request" }),
    );
    expect(
      await screen.findByText("Draft saved. Review the audience next."),
    ).toBeVisible();
    expect(posts[1]).toEqual(posts[0]);
    expect(window.location.hash).toBe("");
  });

  it("never records opening on load or preview; explicit keyboard activation renders plain text", async () => {
    const calls = server();
    render(<CommunicationsWorkspace noticeId={id} mode="notice" />);
    const open = await screen.findByRole("button", {
      name: "Open notice",
    });
    expect(calls.every((c) => !c.body)).toBe(true);
    expect(
      screen.getByText("Openings and receipt confirmations are recorded."),
    ).toBeVisible();
    expect(screen.queryByText("Plain body")).not.toBeInTheDocument();
    open.focus();
    await userEvent.keyboard("{Enter}");
    expect(await screen.findByText("<script>Plain title</script>")).toBeVisible();
    expect(document.querySelector("article script")).toBeNull();
    expect(calls.filter((c) => c.path.endsWith("/open-notice"))).toHaveLength(1);
  });
  it("receipt-off has no confirmation action", async () => {
    server(false);
    render(<CommunicationsWorkspace noticeId={id} mode="notice" />);
    expect(await screen.findByText("No receipt confirmation requested.")).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Confirm receipt" }),
    ).not.toBeInTheDocument();
  });
  it("confirmation follows identifying the opened version and shows the fixed statement", async () => {
    const calls = server();
    render(<CommunicationsWorkspace noticeId={id} mode="notice" />);
    await ensureOpened();
    await userEvent.click(
      await screen.findByRole("button", {
        name: "Confirm receipt",
      }),
    );
    expect(
      await screen.findByText("Receipt confirmed for this version."),
    ).toBeVisible();
    expect(screen.getByText("I acknowledge receipt of this notice.")).toBeVisible();
    expect(calls.filter((c) => c.path.endsWith("/open-notice"))).toHaveLength(1);
  });
  it("write defaults receipt off and associates required errors with fields", async () => {
    server();
    render(<CommunicationsWorkspace mode="write" />);
    expect(
      await screen.findByRole("checkbox", {
        name: "Request receipt confirmation",
      }),
    ).not.toBeChecked();
    await userEvent.click(screen.getByRole("button", { name: "Save draft" }));
    expect(screen.getByLabelText("Title", { exact: true })).toHaveAttribute(
      "aria-invalid",
      "true",
    );
    expect(screen.getByLabelText("Body", { exact: true })).toHaveAttribute(
      "aria-describedby",
      "notice-body-error",
    );
    expect(screen.getByText("Check the highlighted fields.")).toBeVisible();
  });
  it("uncertain confirmation reconciles exact actor-bound outcome without a new command key", async () => {
    const calls = server();
    const original = globalThis.fetch;
    vi.stubGlobal(
      "fetch",
      vi.fn(async (path: string, init?: RequestInit) => {
        if (path.endsWith("/confirm-receipt")) {
          await original(path, init);
          throw new TypeError("Lost response");
        }
        if (path.endsWith("/command-outcome")) {
          calls.push({ path, body: JSON.parse(init!.body as string) });
          return new Response(
            JSON.stringify({
              data: {
                status: "committed",
                result: {
                  notice_id: id,
                  revision_id: revision,
                  fact_id: id,
                  recorded_at: "2026-10-26T09:00:00",
                  kind: "receipt",
                },
              },
            }),
            { status: 200 },
          );
        }
        return original(path, init);
      }),
    );
    render(<CommunicationsWorkspace noticeId={id} mode="notice" />);
    await ensureOpened();
    await userEvent.click(
      await screen.findByRole("button", {
        name: "Confirm receipt",
      }),
    );
    expect(
      await screen.findByText(
        "The result is uncertain. Keep this request until it has been checked.",
      ),
    ).toBeVisible();
    await userEvent.click(screen.getByRole("button", { name: "Check this request" }));
    expect(
      await screen.findByText(
        "The original request was recorded. The current task has been reloaded.",
      ),
    ).toBeVisible();
    expect(calls.find((c) => c.path.endsWith("/command-outcome"))?.body).toMatchObject({
      notice_id: id,
      action: "confirm_receipt",
    });
  });
});
