import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("calendar owner saves, reloads, publishes and resolves one server-selected synthetic year", async ({
  page,
}) => {
  await page.goto("/academic-calendar");

  const signIn = page.getByRole("button", {
    name: "Start synthetic calendar-owner session",
  });
  await expect(signIn.or(page.getByLabel("Academic year label"))).toBeVisible();
  if (await signIn.isVisible()) await signIn.click();

  const status = page.locator(".c-calendar-status");
  await expect(status).toContainText("Saved draft loaded from the school database");
  await expect(page.getByText("Draft saved", { exact: true })).toBeVisible();
  await expect(page.getByLabel("Academic year label")).toHaveValue("Synthetic year");

  for (const width of [1440, 768, 320]) {
    await page.setViewportSize({ width, height: 900 });
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true);
    expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
    await page.locator("body").click({ position: { x: 1, y: 1 } });
    await page.screenshot({
      path: `test-results/calendar-draft-${width}.png`,
      fullPage: true,
    });
  }

  await page.setViewportSize({ width: 1440, height: 900 });
  await page.getByLabel("Year starts").fill("2027-11-01");
  await page.getByRole("button", { name: "Save draft" }).click();
  await expect(page.locator(".c-calendar-errors")).toContainText(
    "The academic year must end on or after its start date.",
  );
  await page.getByRole("button", { name: "Reload from database" }).click();
  await expect(status).toContainText("Saved draft loaded from the school database");
  await expect(page.locator(".c-calendar-errors")).toHaveCount(0);

  await page.getByLabel("Academic year label").fill("Reviewed synthetic year");
  await page.route("**/api/v1/calendar/save-draft", (route) => route.abort());
  await page.getByRole("button", { name: "Save draft" }).click();
  await expect(status).toContainText("Connection interrupted");
  await page.unroute("**/api/v1/calendar/save-draft");
  await page.getByRole("button", { name: "Reload from database" }).click();
  await expect(status).toContainText("Saved draft loaded from the school database");

  const label = page.getByLabel("Academic year label");
  await label.focus();
  await page.keyboard.press("ControlOrMeta+A");
  await page.keyboard.type("Reviewed synthetic year");
  const save = page.getByRole("button", { name: "Save draft" });
  await expect(save).toBeEnabled();
  await save.press("Enter");
  await expect(status).toContainText("Draft saved and read back");
  await page.reload();
  await expect(page.getByLabel("Academic year label")).toHaveValue(
    "Reviewed synthetic year",
  );

  const session = await page.request.get("/api/v1/session");
  const csrf = (await session.json()).data.csrf_token as string;
  const preparation = await page.request.get("/api/v1/calendar/preparation");
  const preparationBody = await preparation.json();
  const rejected = await page.request.post("/api/v1/calendar/save-draft", {
    headers: {
      Origin: "https://localhost:3013",
      "X-CSRF-Token": csrf,
    },
    data: {
      ...preparationBody.data.definition,
      expected_version: preparationBody.data.lock_version,
      idempotency_key: crypto.randomUUID(),
      causation_id: crypto.randomUUID(),
      tenant_id: crypto.randomUUID(),
    },
  });
  expect(rejected.status()).toBe(400);

  const publish = page.getByRole("button", { name: "Publish academic year" });
  await publish.press("Enter");
  await expect(status).toContainText("Academic year published and read back");
  await expect(page.getByText("Published", { exact: true }).first()).toBeVisible();
  await expect(page.getByLabel("Academic year label")).toBeDisabled();
  const resolve = page.getByRole("button", { name: "Resolve date from database" });
  await resolve.press("Enter");
  await expect(status).toContainText("Date resolved from the published calendar");
  await expect(page.getByText("Instructional", { exact: true })).toBeVisible();
  await page.locator("body").click({ position: { x: 1, y: 1 } });
  await page.screenshot({
    path: "test-results/calendar-published.png",
    fullPage: true,
  });
});
