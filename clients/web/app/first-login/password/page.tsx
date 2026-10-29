import { StaffLogin } from "../../../src/components/staff-login";
import { requireStaffDemo } from "../../../src/server/staff-demo";

export const dynamic = "force-dynamic";

export default async function FirstPasswordPage() {
  await requireStaffDemo();
  return <StaffLogin replacing />;
}
