import { defineConfig, devices } from "@playwright/test";

const ui0Port = process.env.CHIMWEMWE_UI0_E2E_PORT ?? "3020";

if (!/^[1-9][0-9]{0,4}$/.test(ui0Port) || Number(ui0Port) > 65_535) {
  throw new Error("CHIMWEMWE_UI0_E2E_PORT must be a valid TCP port.");
}

const ui0BaseUrl = `http://127.0.0.1:${ui0Port}`;

export default defineConfig({
  testDir: "./tests/e2e",
  testIgnore: ["ui1-*.spec.ts"],
  fullyParallel: false,
  forbidOnly: true,
  retries: 0,
  workers: 1,
  reporter: [["line"]],
  use: {
    baseURL: ui0BaseUrl,
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium-wide",
      use: { ...devices["Desktop Chrome"], viewport: { width: 1440, height: 900 } },
    },
    {
      name: "chromium-medium",
      use: { ...devices["Desktop Chrome"], viewport: { width: 768, height: 1024 } },
    },
    {
      name: "chromium-narrow",
      use: { ...devices["Desktop Chrome"], viewport: { width: 320, height: 800 } },
    },
  ],
  webServer: {
    command: "npm run start",
    url: ui0BaseUrl,
    reuseExistingServer: false,
    timeout: 30_000,
    env: {
      CHIMWEMWE_UI0_SYNTHETIC: "true",
      PORT: ui0Port,
    },
  },
});
