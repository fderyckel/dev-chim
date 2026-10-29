import { CommunicationsWorkspace } from "../../src/components/communications-workspace";
import { requireCommunicationsDemo } from "../../src/server/communications-demo";
export const dynamic = "force-dynamic";
export default async function Page() {
  await requireCommunicationsDemo();
  return <CommunicationsWorkspace mode="write" />;
}
