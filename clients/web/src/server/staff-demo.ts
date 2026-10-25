import "server-only";

import { headers } from "next/headers";
import { notFound } from "next/navigation";

// This guard only limits the fictional browser harness. Phoenix owns authority.
export async function requireStaffDemo() {
  if (process.env.CHIMWEMWE_STAFF_DEMO !== "true") notFound();
  const host = (await headers()).get("host") ?? "";
  if (!/^(?:localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$/.test(host)) notFound();
}
