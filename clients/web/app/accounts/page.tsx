import { StaffDirectory } from "../../src/components/staff-directory";
import { requireStaffDemo } from "../../src/server/staff-demo";

export const dynamic = "force-dynamic";

export default async function AccountsPage() {
  await requireStaffDemo();
  return <StaffDirectory />;
}
