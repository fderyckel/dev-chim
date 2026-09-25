import { expect, test } from "@playwright/test";

test("explains recovery when the local core cannot be reached", async ({ page }) => {
  await page.goto("/authority/assignments");

  const status = page.getByRole("status").last();
  await expect(status).toContainText(
    "The browser experience cannot reach the local core",
  );
  await expect(status).toContainText("What to do:");
  await expect(page.getByRole("button")).toHaveCount(0);
});
