import { render, screen } from "@testing-library/react";
import { run as runAccessibilityScan } from "axe-core";
import { describe, expect, it } from "vitest";

import { AssignmentPreparation } from "../../src/components/assignment-preparation";
import { CoreBridgeStateView } from "../../src/components/core-bridge-state";

const data = {
  connection: "local_core",
  contract_version: 1,
  memberships: [
    { id: "membership-1", label: "Synthetic membership 01" },
    { id: "membership-2", label: "Synthetic membership 02" },
  ],
  roles: [{ id: "role-1", label: "Library review" }],
} as const;

describe("the UI-1A assignment preparation components", () => {
  it("renders server options with no enabled write control", async () => {
    render(<AssignmentPreparation data={data} />);

    expect(
      screen.getByRole("heading", { level: 1, name: "Prepare a role assignment" }),
    ).toBeVisible();
    expect(screen.getByRole("combobox", { name: /Membership/ })).toBeVisible();
    expect(screen.getByRole("combobox", { name: /Tenant-defined role/ })).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Save unavailable in UI-1A" }),
    ).toBeDisabled();

    const accessibility = await runAccessibilityScan(document.body, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(accessibility.violations).toEqual([]);
  });

  it.each(["disabled", "denied", "retryable", "unavailable", "unexpected"] as const)(
    "gives the %s state an explicit recovery path",
    (state) => {
      render(<CoreBridgeStateView result={{ state }} />);

      expect(screen.getByRole("status")).toHaveTextContent("What to do:");
      expect(screen.getByRole("status")).toHaveTextContent(/local|reload|restart/i);
    },
  );
});
