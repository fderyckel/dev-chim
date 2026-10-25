import { defineConfig, globalIgnores } from "eslint/config";
import nextCoreWebVitals from "eslint-config-next/core-web-vitals";
import nextTypeScript from "eslint-config-next/typescript";

export default defineConfig([
  ...nextCoreWebVitals,
  ...nextTypeScript,
  globalIgnores([
    ".next/**",
    ".next-check/**",
    ".next-classroom/**",
    ".next-demo/**",
    ".next-staff/**",
    "playwright-report/**",
    "test-results/**",
    "vendor/**",
    "next-env.d.ts",
  ]),
]);
