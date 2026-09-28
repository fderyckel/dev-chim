import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

test("home clearly identifies its synthetic context and primary next step", async ({
  page,
}) => {
  await page.goto("/");

  await expect(
    page.getByRole("heading", { level: 1, name: "A clear place to begin" }),
  ).toBeVisible();
  await expect(page.getByText("Local prototype · synthetic data")).toBeVisible();
  await expect(page.getByText("Synthetic tenant")).toBeVisible();
  await expect(page.getByText("Local fixture · no server connection")).toBeVisible();
  await expect(
    page.getByRole("link", { name: "Review attention items" }),
  ).toBeVisible();
});

test("keyboard navigation reaches the preview and its recovery language", async ({
  page,
}) => {
  await page.goto("/");

  const skipLink = page.getByRole("link", { name: "Skip to main content" });
  await page.keyboard.press("Tab");
  await expect(skipLink).toBeFocused();

  const previewLink = page.getByRole("link", { name: "UI preview" });
  for (let attempt = 0; attempt < 6; attempt += 1) {
    await page.keyboard.press("Tab");
    if (await previewLink.evaluate((element) => element === document.activeElement))
      break;
  }
  await expect(previewLink).toBeFocused();
  await page.keyboard.press("Enter");

  await expect(
    page.getByRole("heading", { level: 1, name: "UI preview" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Access unavailable" }).click();
  await expect(page.getByRole("status").last()).toContainText(
    "You do not have access to this view",
  );
  await expect(page.getByRole("status").last()).toContainText("What to do:");
});

test("the structure prototype separates linked meanings and blocks unknown impacts", async ({
  page,
}) => {
  await page.goto("/institutional-structure");

  await expect(
    page.getByRole("heading", { level: 1, name: "Institutional structure" }),
  ).toBeVisible();
  await expect(
    page.getByRole("list", { name: "Institutional containment" }),
  ).toBeVisible();
  await expect(page.getByText("Separate structures")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Legal entities" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Corporate units" })).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Legal responsibility" }),
  ).toBeVisible();
  await expect(page.getByText("Primary legal operator")).toBeVisible();
  await expect(page.getByText(/Consolidation is not ownership/)).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Transfer review path" }),
  ).toBeVisible();
  await expect(page.getByText("Governed single-controller exception")).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Five representative contexts" }),
  ).toBeVisible();
  const institutionalTree = page.getByRole("list", {
    name: "Institutional containment",
  });
  for (const contextLabel of [
    "Primary / early years · NPES",
    "Secondary school · CSS",
    "Combined formal education · MCS",
    "College / community college · LCC",
    "University · MU",
  ]) {
    await expect(
      institutionalTree.getByText(contextLabel, { exact: true }),
    ).toBeVisible();
  }
  await expect(page.getByRole("heading", { name: "Sites" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Affiliations" })).toBeVisible();
  await expect(page.getByText("Blocks move")).toBeVisible();
  await expect(page.getByText("Blocks transfer")).toBeVisible();
  await expect(page.getByText("Ready for boundary check")).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Legal accountability under review" }),
  ).toBeVisible();
  const accountabilityReview = page.getByRole("region", {
    name: "Legal accountability under review",
  });
  await expect(
    accountabilityReview.getByText("Unavailable", { exact: true }),
  ).toHaveCount(2);
  await expect(page.getByRole("button")).toHaveCount(0);
});

test("local prototype pages reflow without page-level horizontal scrolling", async ({
  page,
}) => {
  for (const path of ["/", "/institutional-structure", "/ui-preview"]) {
    await page.goto(path);
    const widths = await page.evaluate(() => ({
      viewport: window.innerWidth,
      document: document.documentElement.scrollWidth,
    }));

    expect(
      widths.document,
      `${path} should reflow within the viewport`,
    ).toBeLessThanOrEqual(widths.viewport);
  }
});

test("local prototype pages have no automatically detectable accessibility violations", async ({
  page,
}) => {
  for (const path of ["/", "/institutional-structure", "/ui-preview"]) {
    await page.goto(path);
    const result = await new AxeBuilder({ page }).analyze();

    expect(result.violations, `${path} accessibility violations`).toEqual([]);
  }
});
