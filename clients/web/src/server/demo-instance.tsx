import "server-only";

import { headers } from "next/headers";
import Link from "next/link";
import { DemoInstanceView } from "../components/demo-instance-view";
import { loadDemoInstance } from "./demo-instance-loader";

export type DemoSearchParams = Promise<{
  [key: string]: string | string[] | undefined;
}>;

export async function DemoPage({
  section = "overview",
  selection,
}: {
  section?: string;
  selection?: string | string[];
}) {
  const requestHeaders = await headers();
  let data;
  try {
    data = await loadDemoInstance(requestHeaders.get("host"), process.env, selection);
  } catch {
    return (
      <main className="l-main-content">
        <h1>Demo unavailable</h1>
        <p>
          Choose an institution again. If it is still unavailable, restart with{" "}
          <code>make demo</code>.
        </p>
        <Link href="/">Return to demo</Link>
      </main>
    );
  }
  return <DemoInstanceView key={data.packId} data={data} section={section} />;
}
