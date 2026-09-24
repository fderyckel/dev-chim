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
    expect(Object.keys(syntheticViewData).sort()).toEqual(["getHome", "getPreview"]);
  });
});
