import { StaffPreferences } from "../../src/components/staff-preferences";
import { requireStaffDemo } from "../../src/server/staff-demo";

export const dynamic = "force-dynamic";

export default async function PreferencesPage() {
  await requireStaffDemo();
  return <StaffPreferences />;
}
