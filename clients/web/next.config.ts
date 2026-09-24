import { PHASE_PRODUCTION_BUILD } from "next/constants";
import type { NextConfig } from "next";

const SYNTHETIC_UI0_FLAG = "CHIMWEMWE_UI0_SYNTHETIC";

export default function nextConfig(phase: string): NextConfig {
  if (phase === PHASE_PRODUCTION_BUILD && process.env[SYNTHETIC_UI0_FLAG] !== "true") {
    throw new Error(
      `${SYNTHETIC_UI0_FLAG}=true is required to build the local-only UI-0 prototype.`,
    );
  }

  return {
    poweredByHeader: false,
    reactStrictMode: true,
  };
}
