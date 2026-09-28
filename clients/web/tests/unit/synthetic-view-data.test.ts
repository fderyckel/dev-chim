import { afterEach, describe, expect, it, vi } from "vitest";

const flag = "CHIMWEMWE_UI0_SYNTHETIC";
const originalFlag = process.env[flag];

afterEach(() => {
  vi.resetModules();
  if (originalFlag === undefined) {
    delete process.env[flag];
  } else {
    process.env[flag] = originalFlag;
  }
});

describe("the synthetic view-data adapter", () => {
  it("fails closed when its local-only flag is absent", async () => {
    delete process.env[flag];

    await expect(import("../../src/fixtures/synthetic-view-data")).rejects.toThrow(
      "UI-0 synthetic data is disabled",
    );
  });

  it("exposes deterministic reads and no mutation surface", async () => {
    process.env[flag] = "true";
    const { syntheticViewData } =
      await import("../../src/fixtures/synthetic-view-data");

    const firstHome = await syntheticViewData.getHome();
    const secondHome = await syntheticViewData.getHome();
    const structure = await syntheticViewData.getInstitutionalStructure();
    const preview = await syntheticViewData.getPreview();

    expect(secondHome).toEqual(firstHome);
    expect(firstHome.context.tenantKind).toBe("synthetic");
    expect(firstHome.context.connectionLabel).toContain("no server connection");
    expect(preview.states.map((state) => state.key)).toEqual([
      "ready",
      "loading",
      "empty",
      "denied",
      "rate-limited",
      "retryable",
      "conflict",
      "unexpected",
    ]);
    expect(structure.roots).toHaveLength(5);
    expect(structure.roots.map((root) => root.localLabel)).toEqual([
      "Primary / early years",
      "Secondary school",
      "Combined formal education",
      "College / community college",
      "University",
    ]);
    expect(structure.roots.every((root) => root.classification === "institution")).toBe(
      true,
    );
    const selectedInTree = structure.roots
      .flatMap((root) => root.children)
      .flatMap((unit) => unit.children)
      .find((unit) => unit.id === structure.selectedUnit.id);
    expect(selectedInTree?.id).toBe(structure.selectedUnit.id);
    expect(selectedInTree?.classification).toBe(structure.selectedUnit.classification);
    expect(selectedInTree?.localLabel).toBe(structure.selectedUnit.localLabel);
    expect(structure.linkedStructure.legalEntities).toHaveLength(2);
    expect(structure.linkedStructure.corporateOwner).toBe(
      "Mphamvu Education Operations",
    );
    expect(structure.linkedStructure.responsibility.primaryOperator).toBe(
      "Mphamvu Education Operations",
    );
    expect(
      structure.linkedStructure.operatorTransferPreviews.some(
        (transfer) =>
          transfer.state === "blocked" &&
          transfer.impacts.some((impact) => impact.outcome === "blocks_move"),
      ),
    ).toBe(true);
    expect(
      structure.linkedStructure.operatorTransferPreviews.some(
        (transfer) => transfer.state === "ready_for_boundary_check",
      ),
    ).toBe(true);
    expect(
      structure.linkedStructure.operatorGovernance.workflow.map((step) => step.label),
    ).toEqual([
      "Proposed",
      "Evidence verified",
      "Approved",
      "Effective-boundary revalidation",
      "Active",
    ]);
    expect(
      structure.linkedStructure.operatorGovernance.approvalPaths.map(
        (path) => path.label,
      ),
    ).toContain("Governed single-controller exception");
    expect(
      structure.linkedStructure.operatorGovernance.accountabilityReview.actions.map(
        (action) => action.outcome,
      ),
    ).toContain("fails_closed");
    expect(
      structure.movePreview.impacts.some((impact) => impact.outcome === "blocks_move"),
    ).toBe(true);
    expect(Object.keys(syntheticViewData).sort()).toEqual([
      "getHome",
      "getInstitutionalStructure",
      "getPreview",
    ]);
  });
});
