import { DemoPage, type DemoSearchParams } from "../../src/server/demo-instance";

export default async function SelectedDemoPage({
  searchParams,
}: {
  searchParams: DemoSearchParams;
}) {
  return <DemoPage selection={(await searchParams).demo} />;
}
