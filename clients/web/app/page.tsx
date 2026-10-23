import { AppShell } from "../src/components/app-shell";
import { HomeView } from "../src/components/home-view";
import { syntheticViewData } from "../src/fixtures/synthetic-view-data";
import { connection } from "next/server";
import { DemoPage, type DemoSearchParams } from "../src/server/demo-instance";

export default async function HomePage({
  searchParams,
}: {
  searchParams: DemoSearchParams;
}) {
  await connection();
  if (process.env.CHIMWEMWE_DEMO_INSTANCE === "true")
    return <DemoPage selection={(await searchParams).demo} />;
  const viewData = await syntheticViewData.getHome();

  return (
    <AppShell activePage="home" context={viewData.context}>
      <HomeView viewData={viewData} />
    </AppShell>
  );
}
