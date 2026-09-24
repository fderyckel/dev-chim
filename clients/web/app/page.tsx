import { AppShell } from "../src/components/app-shell";
import { HomeView } from "../src/components/home-view";
import { syntheticViewData } from "../src/fixtures/synthetic-view-data";

export default async function HomePage() {
  const viewData = await syntheticViewData.getHome();

  return (
    <AppShell activePage="home" context={viewData.context}>
      <HomeView viewData={viewData} />
    </AppShell>
  );
}
