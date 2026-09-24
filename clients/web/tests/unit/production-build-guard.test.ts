import { afterEach, describe, expect, it } from "vitest";
import { PHASE_PRODUCTION_BUILD, PHASE_DEVELOPMENT_SERVER } from "next/constants";

import nextConfig from "../../next.config";

const flag = "CHIMWEMWE_UI0_SYNTHETIC";
const originalFlag = process.env[flag];

afterEach(() => {
  if (originalFlag === undefined) {
    delete process.env[flag];
  } else {
    process.env[flag] = originalFlag;
  }
});

describe("the local-only production build guard", () => {
  it("fails closed when a production build has no explicit synthetic flag", () => {
    delete process.env[flag];

    expect(() => nextConfig(PHASE_PRODUCTION_BUILD)).toThrow(
      `${flag}=true is required`,
    );
  });

  it("permits a production build only when the exact flag is true", () => {
    process.env[flag] = "true";

    expect(nextConfig(PHASE_PRODUCTION_BUILD)).toMatchObject({
      poweredByHeader: false,
      reactStrictMode: true,
    });
  });

  it("does not mistake a non-production Next phase for a production build", () => {
    delete process.env[flag];

    expect(nextConfig(PHASE_DEVELOPMENT_SERVER)).toMatchObject({
      poweredByHeader: false,
      reactStrictMode: true,
    });
  });
});
