import { StrictMode } from "react";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { StaffWorkspace } from "../../src/components/staff-workspace";
import { staffWorkspaceSections } from "../../src/lib/staff-workspace";
import type { StaffPreference } from "../../src/components/staff-shared";
const self: StaffPreference = {
  id: "fictional-educator",
  display_name: "Fictional educator",
  given_name: null,
  family_name: null,
  locale: "en",
  lock_version: 1,
  navigation: { classroom: true, accounts: false },
};
const classes = [
  { id: "birch", label: "Birch daily register", local_date: "2026-10-27" },
  { id: "willow", label: "Willow daily register", local_date: "2026-10-28" },
];
const register = (saved = false) => ({
  class_id: "birch",
  label: "Birch daily register",
  local_date: "2026-10-27",
  submission_id: saved ? "submission" : null,
  revision_id: saved ? "revision" : null,
  calendar_revision: 1,
  roster_basis: "fictional-roster",
  correction_number: 0,
  students: [{ id: "a", name: "Fictional learner", mark: saved ? "present" : null }],
});
const json = (data: unknown) =>
  new Response(JSON.stringify({ data }), {
    headers: { "Content-Type": "application/json" },
  });
const denied = (status = 401) =>
  new Response(JSON.stringify({ errors: [{ code: "not_authorized" }] }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
function deferred() {
  let resolve!: (response: Response) => void;
  const promise = new Promise<Response>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}
function serve(
  handler?: (request: Request) => Response | Promise<Response> | undefined,
) {
  const BrowserRequest = globalThis.Request;
  vi.stubGlobal(
    "Request",
    class extends BrowserRequest {
      constructor(input: RequestInfo | URL, init?: RequestInit) {
        super(
          typeof input === "string" ? new URL(input, window.location.origin) : input,
          init,
        );
      }
    },
  );
  const requests: string[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const request =
        input instanceof BrowserRequest ? input : new Request(input.toString(), init);
      const path = new URL(request.url).pathname;
      requests.push(path);
      const override = handler?.(request);
      if (override) return override;
      if (path === "/api/v1/session") return json({ csrf_token: "fictional-token" });
      if (path === "/api/v1/staff-preferences") return json(self);
      if (path === "/api/v1/classroom/classes") return json(classes);
      if (path === "/api/v1/classroom/prepare-attendance") return json(register());
      if (path === "/api/v1/session/logout") return new Response(null, { status: 204 });
      throw new Error(`Unexpected request: ${path}`);
    }),
  );
  return requests;
}
async function open(saved = false) {
  const user = userEvent.setup();
  const { ClassroomAttendance } =
    await import("../../src/components/classroom-attendance");
  render(<ClassroomAttendance staffSignIn />);
  await user.click(await screen.findByRole("button", { name: "Birch daily register" }));
  await screen.findByRole(saved ? "button" : "radio", {
    name: saved ? "Correct attendance" : "Present",
  });
  return user;
}
beforeEach(() => {
  // openapi-fetch captures its transport when the workflow module is instantiated.
  vi.resetModules();
  vi.spyOn(HTMLDialogElement.prototype, "showModal").mockImplementation(function (
    this: HTMLDialogElement,
  ) {
    this.setAttribute("open", "");
  });
});
afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});
describe("staff workspace entrances", () => {
  it.each(["home", "apps"] as const)(
    "loads only own presentation on %s",
    async (page) => {
      const requests = serve();
      render(
        <StrictMode>
          <StaffWorkspace page={page} />
        </StrictMode>,
      );
      expect(await screen.findByText("Fictional educator")).toBeVisible();
      expect(screen.getByRole("link", { name: "Classroom" })).toHaveAttribute(
        "href",
        "/classroom",
      );
      expect(screen.queryByRole("link", { name: "Accounts" })).not.toBeInTheDocument();
      expect(new Set(requests)).toEqual(
        new Set(["/api/v1/session", "/api/v1/staff-preferences"]),
      );
      expect(screen.queryByText("Example account")).not.toBeInTheDocument();
    },
  );
  it("allows new group labels and placement while retaining canonical destinations and exact hints", () => {
    const result = staffWorkspaceSections(self, [
      {
        id: "support",
        label: "Student support",
        entries: ["accounts", "classroom", "classroom"],
      },
    ]);
    expect(result[0].label).toBe("Student support");
    expect(result[0].entries.map((entry) => entry.href)).toEqual(["/classroom"]);
  });
  it("keeps own preferences recovery with malformed hints", async () => {
    serve((r) =>
      new URL(r.url).pathname.endsWith("staff-preferences")
        ? json({ ...self, navigation: { classroom: "true", accounts: 1 } })
        : undefined,
    );
    render(<StaffWorkspace page="apps" />);
    await screen.findByText("Fictional educator");
    expect(screen.queryByRole("link", { name: "Classroom" })).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Accounts" })).not.toBeInTheDocument();
    expect(
      screen.getAllByRole("link", { name: "My preferences" }).length,
    ).toBeGreaterThan(0);
  });
  it.each([401, 403])("clears presentation after denial (%s)", async (status) => {
    serve((r) =>
      new URL(r.url).pathname.endsWith("staff-preferences")
        ? denied(status)
        : undefined,
    );
    render(<StaffWorkspace page="home" />);
    expect(await screen.findByRole("link", { name: "Sign in" })).toBeVisible();
    expect(screen.queryByText("Fictional educator")).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Home" })).not.toBeInTheDocument();
  });
  it("rejects self presentation after departure", async () => {
    const pending = deferred();
    const requests = serve((r) =>
      new URL(r.url).pathname.endsWith("staff-preferences")
        ? pending.promise
        : undefined,
    );
    render(<StaffWorkspace page="home" />);
    await waitFor(() => expect(requests).toContain("/api/v1/staff-preferences"));
    await act(async () => {
      window.dispatchEvent(new Event("pagehide"));
      pending.resolve(json(self));
    });
    expect(screen.queryByText("Fictional educator")).not.toBeInTheDocument();
  });
});
describe("Classroom navigation and recovery", () => {
  it.each(["Home", "Apps", "Reload class", "Willow daily register"])(
    "preserves marks and focus on Stay before %s",
    async (label) => {
      const requests = serve();
      const user = await open();
      await user.click(screen.getByRole("radio", { name: "Present" }));
      const origin = ["Home", "Apps"].includes(label)
        ? screen.getByRole("link", { name: label })
        : screen.getByRole("button", { name: label });
      await user.click(origin);
      expect(
        screen.getByRole("dialog", { name: "Discard unsaved marks?" }),
      ).toBeVisible();
      await user.click(screen.getByRole("button", { name: "Stay" }));
      expect(screen.getByRole("radio", { name: "Present" })).toBeChecked();
      await waitFor(() => expect(origin).toHaveFocus());
      expect(requests.filter((p) => p.endsWith("prepare-attendance"))).toHaveLength(1);
    },
  );
  it("requires explicit discard and warns on full departure; Escape keeps the draft", async () => {
    serve();
    const user = await open();
    await user.click(screen.getByRole("radio", { name: "Present" }));
    const event = new Event("beforeunload", { cancelable: true });
    window.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(true);
    await user.click(screen.getByRole("button", { name: "Reload class" }));
    fireEvent(screen.getByRole("dialog"), new Event("cancel", { bubbles: true }));
    expect(screen.getByRole("radio", { name: "Present" })).toBeChecked();
    await user.click(screen.getByRole("button", { name: "Reload class" }));
    await user.click(screen.getByRole("button", { name: "Discard" }));
    await waitFor(() =>
      expect(screen.getByRole("radio", { name: "Present" })).not.toBeChecked(),
    );
  });
  it("blocks ambiguous class label/date choices", async () => {
    serve((r) =>
      new URL(r.url).pathname.endsWith("/classes")
        ? json([
            classes[0],
            { ...classes[0], id: "another", label: "Birch  daily register" },
          ])
        : undefined,
    );
    const { ClassroomAttendance } =
      await import("../../src/components/classroom-attendance");
    render(<ClassroomAttendance staffSignIn />);
    expect(await screen.findByRole("alert")).toHaveTextContent("clarify their labels");
    expect(
      screen
        .getAllByRole("button", { name: "Birch daily register" })
        .every((b) => (b as HTMLButtonElement).disabled),
    ).toBe(true);
  });
  it("blocks cancellation/departure after uncertain correction and reconciles without replay", async () => {
    let corrected = false;
    const requests = serve((r) => {
      const path = new URL(r.url).pathname;
      if (path.endsWith("prepare-attendance"))
        return json(
          corrected
            ? {
                ...register(true),
                revision_id: "next",
                correction_number: 1,
                students: [{ id: "a", name: "Fictional learner", mark: "late" }],
              }
            : register(true),
        );
      if (path.endsWith("correct-attendance")) {
        corrected = true;
        return Promise.reject(new Error("lost response"));
      }
    });
    const user = await open(true);
    await user.click(screen.getByRole("button", { name: "Correct attendance" }));
    await user.click(screen.getByRole("radio", { name: "Late" }));
    await user.click(screen.getByRole("button", { name: "Save correction" }));
    await waitFor(() =>
      expect(screen.getByRole("status")).toHaveTextContent("Connection interrupted"),
    );
    expect(screen.getByRole("button", { name: "Cancel correction" })).toBeDisabled();
    await user.click(screen.getByRole("link", { name: "Apps" }));
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent("reconcile");
    expect(screen.getByRole("button", { name: "Sign out" })).toBeEnabled();
    await user.click(screen.getByRole("button", { name: "Reload class" }));
    expect(screen.getByRole("status")).toHaveTextContent("requested marks are current");
    expect(requests.filter((p) => p.endsWith("correct-attendance"))).toHaveLength(1);
  });
  it.each(["Reload class", "My classes"])(
    "does not restore a reconciled correction after Discard via %s",
    async (target) => {
      serve((r) => {
        const path = new URL(r.url).pathname;
        if (path.endsWith("prepare-attendance")) return json(register(true));
        if (path.endsWith("correct-attendance"))
          return Promise.reject(new Error("lost response"));
      });
      const user = await open(true);
      await user.click(screen.getByRole("button", { name: "Correct attendance" }));
      await user.click(screen.getByRole("radio", { name: "Late" }));
      await user.click(screen.getByRole("button", { name: "Save correction" }));
      await waitFor(() =>
        expect(screen.getByRole("status")).toHaveTextContent("Connection interrupted"),
      );
      await user.click(screen.getByRole("button", { name: "Reload class" }));
      expect(screen.getByRole("status")).toHaveTextContent("No correction was saved");
      await user.click(screen.getByRole("button", { name: target }));
      await user.click(screen.getByRole("button", { name: "Stay" }));
      expect(screen.getByRole("radio", { name: "Late" })).toBeChecked();
      await user.click(screen.getByRole("button", { name: target }));
      await user.click(screen.getByRole("button", { name: "Discard" }));
      if (target === "My classes")
        await user.click(screen.getByRole("button", { name: "Birch daily register" }));
      expect(
        await screen.findByRole("button", { name: "Correct attendance" }),
      ).toBeVisible();
      expect(screen.queryByRole("radio")).not.toBeInTheDocument();
      expect(screen.getByRole("status")).not.toHaveTextContent(
        "No correction was saved",
      );
    },
  );
  it("offers a fresh session retry after initial connection failure", async () => {
    let unavailable = true;
    serve((r) =>
      new URL(r.url).pathname === "/api/v1/session" && unavailable
        ? Promise.reject(new Error("offline"))
        : undefined,
    );
    const { ClassroomAttendance } =
      await import("../../src/components/classroom-attendance");
    render(<ClassroomAttendance staffSignIn />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole("button", { name: "Try again" }));
    unavailable = false;
    await user.click(await screen.findByRole("button", { name: "Try again" }));
    expect(
      await screen.findByRole("button", { name: "Birch daily register" }),
    ).toBeEnabled();
  });
  it("rejects late write responses after sign-out", async () => {
    const pending = deferred();
    const requests = serve((r) =>
      new URL(r.url).pathname.endsWith("submit-attendance")
        ? pending.promise
        : undefined,
    );
    const user = await open();
    await user.click(screen.getByRole("radio", { name: "Present" }));
    await user.click(screen.getByRole("button", { name: "Submit attendance" }));
    await user.click(screen.getByRole("link", { name: "Home" }));
    expect(screen.getByRole("status")).toHaveTextContent(
      "Wait for the current request",
    );
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Sign out" }));
    await waitFor(() =>
      expect(screen.getByRole("status")).toHaveTextContent("Signed out"),
    );
    await act(async () => pending.resolve(json({ id: "receipt" })));
    expect(screen.queryByText("Fictional learner")).not.toBeInTheDocument();
    expect(screen.queryByText("Fictional educator")).not.toBeInTheDocument();
    expect(requests.filter((p) => p.endsWith("prepare-attendance"))).toHaveLength(1);
  });
  it("clears roster and identity after authority refusal", async () => {
    let refused = false;
    serve((r) =>
      new URL(r.url).pathname.endsWith("prepare-attendance") && refused
        ? denied(403)
        : undefined,
    );
    const user = await open();
    refused = true;
    await user.click(screen.getByRole("button", { name: "Reload class" }));
    expect(await screen.findByRole("link", { name: "Sign in" })).toBeVisible();
    expect(screen.queryByText("Fictional learner")).not.toBeInTheDocument();
    expect(screen.queryByText("Fictional educator")).not.toBeInTheDocument();
  });
  it("never reconciles an earlier uncertain result with a new-day read", async () => {
    let nextDay = false;
    const requests = serve((r) => {
      const path = new URL(r.url).pathname;
      if (path.endsWith("prepare-attendance"))
        return json({
          ...register(),
          local_date: nextDay ? "2026-10-28" : "2026-10-27",
        });
      if (path.endsWith("submit-attendance")) {
        nextDay = true;
        return Promise.reject(new Error("lost response"));
      }
    });
    const user = await open();
    await user.click(screen.getByRole("radio", { name: "Present" }));
    await user.click(screen.getByRole("button", { name: "Submit attendance" }));
    await waitFor(() =>
      expect(screen.getByRole("status")).toHaveTextContent("Connection interrupted"),
    );
    await user.click(screen.getByRole("button", { name: "Reload class" }));
    expect(screen.getByRole("status")).toHaveTextContent(
      "cannot confirm the earlier result",
    );
    expect(
      screen.getByRole("heading", { name: /Attendance · Birch/ }),
    ).toHaveTextContent("2026-10-27");
    expect(screen.getByRole("button", { name: "Submit attendance" })).toBeDisabled();
    expect(requests.filter((p) => p.endsWith("submit-attendance"))).toHaveLength(1);
  });
});
