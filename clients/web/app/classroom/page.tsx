import { notFound } from "next/navigation";
import { ClassroomAttendance } from "../../src/components/classroom-attendance";
import { requireStaffDemo } from "../../src/server/staff-demo";
export const dynamic = "force-dynamic";
export default async function ClassroomPage() {
  const staffSignIn = process.env.CHIMWEMWE_STAFF_DEMO === "true";
  if (staffSignIn) await requireStaffDemo();
  else if (process.env.CHIMWEMWE_CLASSROOM_DEMO !== "true") notFound();
  return <ClassroomAttendance staffSignIn={staffSignIn} />;
}
