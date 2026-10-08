import { notFound } from "next/navigation";
import { ClassroomAttendance } from "../../src/components/classroom-attendance";
export const dynamic = "force-dynamic";
export default function ClassroomPage() {
  if (process.env.CHIMWEMWE_CLASSROOM_DEMO !== "true") notFound();
  return <ClassroomAttendance />;
}
