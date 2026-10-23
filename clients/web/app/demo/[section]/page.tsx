import { notFound } from "next/navigation";
import { DemoPage } from "../../../src/server/demo-instance";

export default async function DemoSection({
  params,
}: {
  params: Promise<{ section: string }>;
}) {
  const { section } = await params;
  if (!["students", "contacts", "educators", "calendar"].includes(section)) notFound();
  return <DemoPage section={section} />;
}
