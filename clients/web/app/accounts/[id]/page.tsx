import { StaffDirectory } from "../../../src/components/staff-directory";
import { requireStaffDemo } from "../../../src/server/staff-demo";

export const dynamic = "force-dynamic";

export default async function AccountPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireStaffDemo();
  const { id } = await params;
  return <StaffDirectory accountId={id} />;
}
