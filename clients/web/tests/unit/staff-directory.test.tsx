import { StrictMode } from "react";
import { act, cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { StaffDirectory } from "../../src/components/staff-directory";
import type {
  StaffAccount,
  StaffInventory,
  StaffPreference,
} from "../../src/components/staff-shared";

const profile = { id: "fictional-classroom-profile", label: "Classroom teacher" };
const account = (id: string, name: string): StaffAccount => ({
  id,
  account_id: id,
  actor_id: `actor-${id}`,
  association_id: `association-${id}`,
  membership_id: `membership-${id}`,
  display_name: name,
  email: `${id}@fictional-school.test`,
  enabled: true,
  source_current: true,
  access_state: "enabled",
  status: "active",
  given_name: null,
  family_name: null,
  locale: "en",
  lock_version: 1,
  roles: [],
  temporary_password_expires_at: null,
});
const first = account("first", "First fictional staff member");
const second = account("second", "Second fictional staff member");
const inventory: StaffInventory = {
  accounts: [first, second],
  eligible_staff: [],
  profiles: [profile],
  institution_label: "Fictional institution",
  locale: "en",
  truncated: false,
};
const self: StaffPreference = {
  id: "operator",
  given_name: null,
  family_name: null,
  display_name: "Fictional operator",
  locale: "en",
  lock_version: 1,
  navigation: { accounts: true, classroom: false },
};
const json = (data: unknown) =>
  new Response(JSON.stringify({ data }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
function deferred() {
  let resolve!: (response: Response) => void;
  const promise = new Promise<Response>((finish) => {
    resolve = finish;
  });
  return { promise, resolve };
}
function delayedInventory(action?: ReturnType<typeof deferred>) {
  const pending: ReturnType<typeof deferred>[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn((input: RequestInfo | URL) => {
      const path = new URL(input.toString(), window.location.origin).pathname;
      if (path === "/api/v1/session")
        return Promise.resolve(
          json({
            csrf_token: "fictional-test-token",
            actor_id: "fictional-operator",
          }),
        );
      if (path === "/api/v1/staff-preferences") return Promise.resolve(json(self));
      if (path === "/api/v1/staff-accounts/set-access" && action) return action.promise;
      if (path === "/api/v1/staff-accounts") {
        const response = deferred();
        pending.push(response);
        return response.promise;
      }
      throw new Error(`Unexpected request: ${path}`);
    }),
  );
  return pending;
}
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("staff directory request lifetime", () => {
  it("keeps a chosen access profile when an older arrival load finishes later", async () => {
    const pending = delayedInventory();
    render(
      <StrictMode>
        <StaffDirectory accountId={first.id} />
      </StrictMode>,
    );
    await waitFor(() => expect(pending.length).toBeGreaterThan(0));
    const latest = pending.at(-1)!;
    await act(async () => latest.resolve(json(inventory)));
    const user = userEvent.setup();
    await user.selectOptions(
      await screen.findByRole("combobox", { name: "Access profile" }),
      profile.id,
    );
    await act(async () => {
      for (const older of pending.filter((request) => request !== latest))
        older.resolve(json(inventory));
    });
    expect(screen.getByRole("combobox", { name: "Access profile" })).toHaveValue(
      profile.id,
    );
    expect(screen.getByRole("button", { name: "Add access profile" })).toBeEnabled();
  });

  it("waits for the new account's authorized load before showing its editing form", async () => {
    const pending = delayedInventory();
    const { rerender } = render(<StaffDirectory accountId={first.id} />);
    await waitFor(() => expect(pending).toHaveLength(1));
    await act(async () => pending[0].resolve(json(inventory)));
    await screen.findByRole("combobox", { name: "Access profile" });
    rerender(<StaffDirectory accountId={second.id} />);
    expect(screen.queryByRole("combobox", { name: "Access profile" })).toBeNull();
    await waitFor(() => expect(pending).toHaveLength(2));
    await act(async () =>
      pending[1].resolve(
        new Response(JSON.stringify({ errors: [{ code: "forbidden" }] }), {
          status: 403,
        }),
      ),
    );
    expect(screen.queryByRole("button", { name: "Add access profile" })).toBeNull();
    expect(screen.queryByText("Fictional operator")).toBeNull();
  });

  it("does not restore account data or identity after page departure", async () => {
    const pending = delayedInventory();
    render(<StaffDirectory accountId={first.id} />);
    await waitFor(() => expect(pending).toHaveLength(1));
    await act(async () => {
      window.dispatchEvent(new Event("pagehide"));
      pending[0].resolve(json(inventory));
    });
    expect(screen.queryByRole("combobox", { name: "Access profile" })).toBeNull();
    expect(screen.queryByText("Fictional operator")).toBeNull();
    expect(screen.queryByRole("button", { name: "Add access profile" })).toBeNull();
  });

  it("does not refresh or reveal an action result after page departure", async () => {
    const action = deferred();
    const pending = delayedInventory(action);
    render(<StaffDirectory accountId={first.id} />);
    await waitFor(() => expect(pending).toHaveLength(1));
    await act(async () => pending[0].resolve(json(inventory)));
    const user = userEvent.setup();
    await user.selectOptions(
      await screen.findByRole("combobox", { name: "Access profile" }),
      profile.id,
    );
    await user.click(screen.getByRole("button", { name: "Add access profile" }));
    const write = vi
      .mocked(fetch)
      .mock.calls.find(([path]) => path.toString().endsWith("/set-access"))!;
    expect(JSON.parse(write[1]!.body as string)).toMatchObject({
      id: first.id,
      profile_id: profile.id,
      expected_version: 1,
    });
    expect(write[1]!.headers).toMatchObject({ "X-CSRF-Token": "fictional-test-token" });
    await act(async () => {
      window.dispatchEvent(new Event("pagehide"));
      action.resolve(json({ temporary_password: null }));
    });
    expect(pending).toHaveLength(1);
    expect(screen.queryByText("Fictional operator")).toBeNull();
    expect(screen.queryByRole("combobox", { name: "Access profile" })).toBeNull();
  });

  it("confirms a normal access action through a fresh authorized inventory", async () => {
    const action = deferred();
    const pending = delayedInventory(action);
    render(<StaffDirectory accountId={first.id} />);
    await waitFor(() => expect(pending).toHaveLength(1));
    await act(async () => pending[0].resolve(json(inventory)));
    const user = userEvent.setup();
    await user.selectOptions(
      await screen.findByRole("combobox", { name: "Access profile" }),
      profile.id,
    );
    await user.click(screen.getByRole("button", { name: "Add access profile" }));
    await act(async () => action.resolve(json({ temporary_password: null })));
    await waitFor(() => expect(pending).toHaveLength(2));
    await act(async () =>
      pending[1].resolve(
        json({
          ...inventory,
          accounts: [{ ...first, roles: [profile], lock_version: 2 }, second],
        }),
      ),
    );
    expect(await screen.findByText("Access profile added.")).toBeVisible();
    expect(screen.getByText("Current roles: Classroom teacher")).toBeVisible();
    expect(screen.getByRole("button", { name: "Add access profile" })).toBeDisabled();
  });

  it("keeps retry and sign-out after an authenticated load fails, then reloads safely", async () => {
    const pending = delayedInventory();
    render(<StaffDirectory accountId={first.id} />);
    await waitFor(() => expect(pending).toHaveLength(1));
    await act(async () =>
      pending[0].resolve(
        new Response(JSON.stringify({ errors: [{ code: "unavailable" }] }), {
          status: 500,
        }),
      ),
    );
    expect(screen.queryByRole("combobox", { name: "Access profile" })).toBeNull();
    expect(screen.queryByText("Fictional operator")).toBeNull();
    expect(screen.getByRole("button", { name: "Sign out" })).toBeEnabled();
    const user = userEvent.setup();
    await user.click(screen.getByRole("button", { name: "Reload status" }));
    await waitFor(() => expect(pending).toHaveLength(2));
    await act(async () => pending[1].resolve(json(inventory)));
    await user.selectOptions(
      await screen.findByRole("combobox", { name: "Access profile" }),
      profile.id,
    );
    expect(screen.getByRole("button", { name: "Add access profile" })).toBeEnabled();
  });
});
