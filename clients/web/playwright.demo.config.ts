import { execFileSync } from "node:child_process";
import path from "node:path";
import { defineConfig } from "@playwright/test";

const packs = [
  "bangkok-international",
  "us-community-college",
  "hong-kong-kindergarten",
  "england-independent",
];
const instances = packs.map((slug) =>
  execFileSync(
    "mise",
    [
      "exec",
      "--",
      "uv",
      "run",
      "python",
      "tools/demo_instance.py",
      "--institution",
      slug,
    ],
    { cwd: path.resolve("../.."), encoding: "utf8" },
  ).trim(),
);

export default defineConfig({
  outputDir: "./playwright-report/demo-instance-results",
  testDir: "./tests/demo",
  fullyParallel: false,
  forbidOnly: true,
  retries: 0,
  workers: 1,
  reporter: [["line"]],
  use: { trace: "retain-on-failure" },
  projects: packs.map((slug, i) => ({
    name: slug,
    use: {
      baseURL: `http://127.0.0.1:${3025 + i}`,
      viewport: { width: 1440, height: 900 },
    },
  })),
  webServer: packs.map((slug, i) => ({
    command: "npm run start",
    url: `http://127.0.0.1:${3025 + i}`,
    reuseExistingServer: false,
    timeout: 30000,
    env: {
      CHIMWEMWE_UI0_SYNTHETIC: "true",
      CHIMWEMWE_DEMO_INSTANCE: "true",
      CHIMWEMWE_DEMO_PACK_ID: slug,
      CHIMWEMWE_DEMO_DATA_DIRECTORY: instances[i],
      PORT: String(3025 + i),
    },
  })),
});
