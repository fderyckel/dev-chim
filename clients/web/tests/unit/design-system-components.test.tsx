import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";

import { ActionButton, ActionLink } from "../../src/design-system/components/actions";
import { ExperienceProfilePreview } from "../../src/design-system/components/experience-profile-preview";
import { PageHeading } from "../../src/design-system/components/page-heading";
import { Panel } from "../../src/design-system/components/panel";
import { StatusBadge } from "../../src/design-system/components/status-badge";

describe("the semantic design-system components", () => {
  it("keeps document hierarchy separate from visual tone", () => {
    render(
      <>
        <PageHeading
          eyebrow="Review surface"
          title="One page title"
          description="Supporting copy"
          aside={<StatusBadge tone="positive">Ready</StatusBadge>}
        />
        <Panel
          eyebrow="Meaningful group"
          title="A section title"
          titleId="section-title"
          badge={<StatusBadge tone="attention">Needs review</StatusBadge>}
        >
          <p>Panel content</p>
        </Panel>
      </>,
    );

    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "One page title",
    );
    expect(screen.getByRole("heading", { level: 2 })).toHaveTextContent(
      "A section title",
    );
    expect(screen.getByRole("region", { name: "A section title" })).toBeVisible();
    expect(screen.getByText("Needs review")).toHaveClass("c-status--attention");
  });

  it("offers only the governed action variants and icon positions", () => {
    render(
      <>
        <ActionLink href="/ui-preview" icon="forward" variant="quiet">
          Open preview
        </ActionLink>
        <ActionButton disabled icon="down" variant="primary">
          Save unavailable
        </ActionButton>
      </>,
    );

    expect(screen.getByRole("link", { name: "Open preview" })).toHaveClass(
      "c-button--quiet",
    );
    expect(screen.getByRole("button", { name: "Save unavailable" })).toBeDisabled();
  });

  it("previews allowlisted profiles in memory and resets on request or unmount", async () => {
    const user = userEvent.setup();
    const { unmount } = render(<ExperienceProfilePreview />);

    expect(document.documentElement).not.toHaveAttribute("data-theme");
    expect(screen.getByRole("radio", { name: /Quiet light/ })).toBeChecked();

    await user.click(screen.getByRole("radio", { name: /Calm dark/ }));
    expect(document.documentElement).toHaveAttribute("data-theme", "dark");
    expect(screen.getByRole("status")).toHaveTextContent(
      "Calm dark is shown locally. It is not saved.",
    );

    await user.click(
      screen.getByRole("button", { name: "Reset to Chimwemwe default" }),
    );
    expect(document.documentElement).not.toHaveAttribute("data-theme");
    expect(
      screen.getByRole("button", { name: "Reset to Chimwemwe default" }),
    ).toBeDisabled();

    await user.click(screen.getByRole("radio", { name: /Clear reading/ }));
    expect(document.documentElement).toHaveAttribute("data-theme", "readable");
    expect(window.localStorage).toHaveLength(0);
    expect(window.sessionStorage).toHaveLength(0);

    unmount();
    expect(document.documentElement).not.toHaveAttribute("data-theme");
  });
});
