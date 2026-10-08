import { render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

describe("the classroom attendance sign-in entry", () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("shows the school-account route only when the explicit build flag is enabled", async () => {
    vi.stubEnv("NEXT_PUBLIC_CHIMWEMWE_OIDC_SIGN_IN", "true");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            errors: [{ code: "unauthenticated", detail: "Sign-in required." }],
          }),
          { status: 401, headers: { "content-type": "application/json" } },
        ),
      ),
    );

    const { ClassroomAttendance } =
      await import("../../src/components/classroom-attendance");

    render(<ClassroomAttendance />);

    expect(
      screen.getByRole("link", { name: "Sign in with your school account" }),
    ).toHaveAttribute("href", "/auth/sign-in");
    expect(
      screen.queryByRole("button", { name: "Start synthetic educator session" }),
    ).not.toBeInTheDocument();

    expect(
      screen.getByText(
        /School account sign-in is available for the pre-linked educator/,
      ),
    ).toBeVisible();
  });
});
