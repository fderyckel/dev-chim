import "server-only";

import { headers } from "next/headers";
import { DemoInstanceView } from "../components/demo-instance-view";
import { loadDemoInstance } from "./demo-instance-loader";

export async function DemoPage({ section = "overview" }: { section?: string }) {
  const requestHeaders = await headers();
  let data;
  try {
    data = await loadDemoInstance(requestHeaders.get("host"));
  } catch {
    return (
      <main className="l-main-content">
        <h1>Demo unavailable</h1>
        <p>
          Restart with <code>make demo</code> and choose an institution.
        </p>
      </main>
    );
  }
  return <DemoInstanceView data={data} section={section} />;
}
