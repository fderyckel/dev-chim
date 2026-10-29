import { CommunicationsWorkspace } from "../../../src/components/communications-workspace";
import { requireCommunicationsDemo } from "../../../src/server/communications-demo";
export const dynamic = "force-dynamic";
export default async function Page({
  params,
}: {
  params: Promise<{ noticeId: string }>;
}) {
  await requireCommunicationsDemo();
  return <CommunicationsWorkspace noticeId={(await params).noticeId} mode="notice" />;
}
