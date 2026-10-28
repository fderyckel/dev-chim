import { defineConfig, devices } from "@playwright/test";
export default defineConfig({
  testDir: "./tests/communications",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: true,
  timeout: 180_000,
  reporter: [["line"]],
  use: {
    ...devices["Desktop Chrome"],
    baseURL: "https://localhost:3025",
    ignoreHTTPSErrors: true,
    actionTimeout: 15_000,
    trace: "off",
    screenshot: "off",
    video: "off",
  },
  webServer: {
    command: "../../bin/communications-demo",
    url: "https://localhost:3025/communications",
    ignoreHTTPSErrors: true,
    reuseExistingServer: false,
    timeout: 180_000,
  },
});
