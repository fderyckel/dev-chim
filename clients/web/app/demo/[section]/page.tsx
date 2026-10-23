import { notFound } from "next/navigation";
import { DemoPage, type DemoSearchParams } from "../../../src/server/demo-instance";

export default async function DemoSection({
  params,
  searchParams,
}: {
  params: Promise<{ section: string }>;
  searchParams: DemoSearchParams;
}) {
  const { section } = await params;
  if (!["students", "contacts", "educators", "calendar"].includes(section)) notFound();
  return <DemoPage section={section} selection={(await searchParams).demo} />;
}
