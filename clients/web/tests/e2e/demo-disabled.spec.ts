import { expect, test } from "@playwright/test";

test("institution data stays unavailable outside an explicit demo instance", async ({
  page,
}) => {
  await page.goto("/demo?institution=bangkok-international");
  await expect(page.getByRole("heading", { name: "Demo unavailable" })).toBeVisible();
  await expect(
    page.getByText("Lotus Grove International School (Demo)", { exact: true }),
  ).toHaveCount(0);
});
