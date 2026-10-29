import { defineConfig, devices } from "@playwright/test";
export default defineConfig({
  testDir: "./tests/classroom",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: true,
  timeout: 60_000,
  reporter: [["line"]],
  use: {
    ...devices["Desktop Chrome"],
    baseURL: "https://localhost:3013",
    ignoreHTTPSErrors: true,
    trace: "retain-on-failure",
  },
  webServer: {
    command: "../../bin/classroom-demo",
    url: "https://localhost:3013/classroom",
    ignoreHTTPSErrors: true,
    reuseExistingServer: false,
    timeout: 120_000,
  },
});
