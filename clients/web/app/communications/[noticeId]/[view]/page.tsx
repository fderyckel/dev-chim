import { notFound } from "next/navigation";
import { CommunicationsWorkspace } from "../../../../src/components/communications-workspace";
import { requireCommunicationsDemo } from "../../../../src/server/communications-demo";
export const dynamic = "force-dynamic";
export default async function Page({
  params,
}: {
  params: Promise<{ noticeId: string; view: string }>;
}) {
  await requireCommunicationsDemo();
  const { noticeId, view } = await params;
  if (view !== "write" && view !== "review" && view !== "metrics") notFound();
  return <CommunicationsWorkspace noticeId={noticeId} mode={view} />;
}
