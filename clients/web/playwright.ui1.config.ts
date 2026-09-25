import { defineConfig, devices } from "@playwright/test";

const testToken = "ui1-playwright-local-token-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

export default defineConfig({
  testDir: "./tests/e2e",
  testMatch: "ui1-connected.spec.ts",
  fullyParallel: false,
  forbidOnly: true,
  retries: 0,
  workers: 1,
  reporter: [["line"]],
  use: {
    baseURL: "http://127.0.0.1:3011",
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "ui1-wide",
      use: { ...devices["Desktop Chrome"], viewport: { width: 1440, height: 900 } },
    },
    {
      name: "ui1-medium",
      use: { ...devices["Desktop Chrome"], viewport: { width: 768, height: 1024 } },
    },
    {
      name: "ui1-narrow",
      use: { ...devices["Desktop Chrome"], viewport: { width: 320, height: 800 } },
    },
  ],
  webServer: [
    {
      command: "../../bin/ui1-test-backend",
      url: "http://127.0.0.1:4011/api/v1/authority/assignment-options",
      reuseExistingServer: false,
      timeout: 60_000,
    },
    {
      command: "npm run dev -- --port 3011",
      url: "http://127.0.0.1:3011/authority/assignments",
      reuseExistingServer: false,
      timeout: 60_000,
      env: {
        CHIMWEMWE_UI0_SYNTHETIC: "true",
        CHIMWEMWE_UI1_API_URL: "http://127.0.0.1:4011",
        CHIMWEMWE_UI1_BRIDGE_TOKEN: testToken,
        CHIMWEMWE_UI1_LOCAL: "true",
      },
    },
  ],
});
