import { StaffWorkspace } from "../../../src/components/staff-workspace";
import { requireStaffDemo } from "../../../src/server/staff-demo";

export const dynamic = "force-dynamic";
export default async function StaffHomePage() {
  await requireStaffDemo();
  return <StaffWorkspace page="home" />;
}
