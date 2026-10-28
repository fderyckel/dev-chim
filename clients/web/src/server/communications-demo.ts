import "server-only";
import { headers } from "next/headers";
import { notFound } from "next/navigation";
export async function requireCommunicationsDemo() {
  if (process.env.CHIMWEMWE_COMM_DEMO !== "true") notFound();
  const host = (await headers()).get("host") ?? "";
  if (!/^(?:localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$/.test(host)) notFound();
}
