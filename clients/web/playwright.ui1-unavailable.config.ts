import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  testMatch: "ui1-unavailable.spec.ts",
  fullyParallel: false,
  forbidOnly: true,
  retries: 0,
  workers: 1,
  reporter: [["line"]],
  use: {
    ...devices["Desktop Chrome"],
    baseURL: "http://127.0.0.1:3012",
    trace: "retain-on-failure",
  },
  webServer: {
    command: "npm run dev -- --port 3012",
    url: "http://127.0.0.1:3012/authority/assignments",
    reuseExistingServer: false,
    timeout: 60_000,
    env: {
      CHIMWEMWE_UI0_SYNTHETIC: "true",
      CHIMWEMWE_UI1_API_URL: "http://127.0.0.1:4099",
      CHIMWEMWE_UI1_BRIDGE_TOKEN:
        "ui1-playwright-unavailable-token-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      CHIMWEMWE_UI1_LOCAL: "true",
    },
  },
});
