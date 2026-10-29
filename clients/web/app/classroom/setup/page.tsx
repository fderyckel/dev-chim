import { notFound } from "next/navigation";
import { ClassroomPreparation } from "../../../src/components/classroom-preparation";

export const dynamic = "force-dynamic";

export default function ClassroomSetupPage() {
  if (process.env.CHIMWEMWE_CLASSROOM_DEMO !== "true") notFound();
  return <ClassroomPreparation />;
}
