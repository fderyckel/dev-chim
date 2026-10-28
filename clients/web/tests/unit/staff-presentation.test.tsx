import { act, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  StaffDestinations,
  type StaffPreference,
} from "../../src/components/staff-shared";
import { StaffPreferences } from "../../src/components/staff-preferences";

const self: StaffPreference = {
  id: "reviewer",
  given_name: null,
  family_name: null,
  display_name: "Primary reviewer",
  locale: "en",
  lock_version: 1,
  navigation: { accounts: false, classroom: true },
};

function authenticatedClassroom(presentation: StaffPreference = self) {
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
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL) => {
      const request = input instanceof Request ? input : new Request(input.toString());
      const path = new URL(request.url).pathname;
      let data: unknown;
      if (path === "/api/v1/session") data = { csrf_token: "fictional-test-state" };
      else if (path === "/api/v1/staff-preferences") data = presentation;
      else if (path === "/api/v1/classroom/classes")
        data = [
          { id: "birch", label: "Birch daily register", local_date: "2026-10-25" },
          { id: "willow", label: "Willow daily register", local_date: "2026-10-25" },
        ];
      else if (path === "/api/v1/classroom/prepare-attendance") {
        const { class_id: id } = await request.clone().json();
        data = {
          class_id: id,
          label: id === "birch" ? "Birch daily register" : "Willow daily register",
          local_date: "2026-10-25",
          submission_id: null,
          revision_id: null,
          calendar_revision: 1,
          roster_basis: "fictional-roster",
          correction_number: 0,
          students:
            id === "birch"
              ? [{ id: "a", name: "Amara Vale", mark: null }]
              : [
                  { id: "b", name: "Ben Rivera", mark: null },
                  { id: "c", name: "Chipo Moss", mark: null },
                ],
        };
      } else throw new Error("Unexpected request in presentation test");
      return new Response(JSON.stringify({ data }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }),
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("staff self presentation", () => {
  it("shows only confirmed destinations and hides missing old-server hints", () => {
    const { rerender } = render(<StaffDestinations locale="en" presentation={self} />);
    expect(screen.queryByRole("link", { name: "Accounts" })).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: "My classes" })).toHaveAttribute(
      "href",
      "/classroom",
    );
    rerender(
      <StaffDestinations
        locale="en"
        presentation={{ ...self, navigation: undefined } as unknown as StaffPreference}
      />,
    );
    expect(screen.queryByRole("link", { name: "My classes" })).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: "My preferences" })).toBeVisible();
  });

  it.each([false, true])(
    "shows the classroom-language note only with classroom access (%s)",
    async (classroom) => {
      authenticatedClassroom({ ...self, navigation: { accounts: false, classroom } });
      render(<StaffPreferences />);
      expect(
        await screen.findByText("Signed in as", { exact: false }),
      ).toHaveTextContent("Primary reviewer");
      expect(
        Boolean(screen.queryByText(/Classroom pages are currently in English/)),
      ).toBe(classroom);
    },
  );

  it("warns before dropping unsaved marks and keeps them when switching is cancelled", async () => {
    authenticatedClassroom();
    const { ClassroomAttendance } =
      await import("../../src/components/classroom-attendance");
    const user = userEvent.setup();
    render(<ClassroomAttendance staffSignIn />);
    await user.click(
      await screen.findByRole("button", { name: "Birch daily register" }),
    );
    expect(await screen.findByText("1 student · 1 still to mark")).toBeVisible();
    expect(screen.getByText("Signed in as", { exact: false })).toHaveTextContent(
      "Primary reviewer",
    );
    await user.click(screen.getByRole("radio", { name: "Present" }));
    await user.click(screen.getByRole("button", { name: "Willow daily register" }));
    expect(
      screen.getByRole("dialog", { name: "Discard unsaved marks?" }),
    ).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Stay" }));
    expect(screen.getByRole("heading", { name: "Birch daily register" })).toBeVisible();
    expect(screen.getByRole("radio", { name: "Present" })).toBeChecked();
    await user.click(screen.getByRole("button", { name: "Willow daily register" }));
    await user.click(screen.getByRole("button", { name: "Discard" }));
    expect(await screen.findByText("2 students · 2 still to mark")).toBeVisible();
    expect(screen.queryByText("Amara Vale")).not.toBeInTheDocument();
    expect(
      screen
        .getAllByRole("radio")
        .every((radio) => !(radio as HTMLInputElement).checked),
    ).toBe(true);
    await act(async () => {
      window.dispatchEvent(new Event("pagehide"));
    });
    expect(
      screen.queryByText("Signed in as", { exact: false }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("Ben Rivera")).not.toBeInTheDocument();
  });
});
