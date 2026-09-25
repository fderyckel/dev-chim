import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

const route = "/authority/assignments";
const testToken = "ui1-playwright-local-token-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

test("reads tenant-qualified options without exposing a browser mutation", async ({
  page,
}) => {
  const requests: string[] = [];
  page.on("request", (request) => requests.push(request.url()));

  await page.goto(route);

  await expect(
    page.getByRole("heading", { level: 1, name: "Prepare a role assignment" }),
  ).toBeVisible();
  await expect(page.getByText("Core read ready")).toBeVisible();
  await expect(page.getByLabel("Membership")).toContainText("Synthetic membership 03");
  await expect(page.getByLabel("Tenant-defined role")).toContainText(
    "Operations review",
  );
  await expect(page.getByText("Separate tenant role")).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: "Save unavailable in UI-1A" }),
  ).toBeDisabled();

  const html = await page.content();
  expect(html).not.toContain(testToken);
  expect(html).not.toContain("71111111-1111-4111-8111-111111111111");
  expect(requests.some((url) => url.startsWith("http://127.0.0.1:4011"))).toBe(false);
});

test("is keyboard-usable, accessible, and contained within the viewport", async ({
  page,
}) => {
  await page.goto(route);

  await page.keyboard.press("Tab");
  await expect(page.getByRole("link", { name: "Skip to main content" })).toBeFocused();

  const widths = await page.evaluate(() => ({
    viewport: window.innerWidth,
    document: document.documentElement.scrollWidth,
  }));
  expect(widths.document).toBeLessThanOrEqual(widths.viewport);

  const result = await new AxeBuilder({ page }).analyze();
  expect(result.violations).toEqual([]);
});
