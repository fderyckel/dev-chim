import { defineConfig, devices } from "@playwright/test";
import { tmpdir } from "node:os";
import { join } from "node:path";

const credentialFile =
  process.env.CHIMWEMWE_STAFF_CREDENTIAL_FILE ??
  join(tmpdir(), `chimwemwe-staff-browser-${process.pid}.json`);
process.env.CHIMWEMWE_STAFF_CREDENTIAL_FILE = credentialFile;

export default defineConfig({
  testDir: "./tests/staff",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: true,
  timeout: 120_000,
  reporter: [["line"]],
  use: {
    ...devices["Desktop Chrome"],
    baseURL: "https://localhost:3015",
    ignoreHTTPSErrors: true,
    actionTimeout: 15_000,
    // Credentials occur in this journey; never retain automatic browser captures.
    trace: "off",
    screenshot: "off",
    video: "off",
  },
  webServer: {
    command: "../../bin/staff-demo",
    url: "https://localhost:3015/sign-in",
    ignoreHTTPSErrors: true,
    reuseExistingServer: false,
    timeout: 180_000,
    env: { CHIMWEMWE_STAFF_CREDENTIAL_FILE: credentialFile },
  },
});
