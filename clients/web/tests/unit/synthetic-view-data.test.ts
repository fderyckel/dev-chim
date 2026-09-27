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
    expect(structure.roots).toHaveLength(3);
    expect(structure.roots.map((root) => root.localLabel)).toEqual([
      "University",
      "Community college",
      "Early Learning Centre",
    ]);
    expect(structure.roots.every((root) => root.classification === "institution")).toBe(
      true,
    );
    const selectedInTree = structure.roots[0]?.children[0]?.children[0];
    expect(selectedInTree?.id).toBe(structure.selectedUnit.id);
    expect(selectedInTree?.classification).toBe(structure.selectedUnit.classification);
    expect(selectedInTree?.localLabel).toBe(structure.selectedUnit.localLabel);
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
