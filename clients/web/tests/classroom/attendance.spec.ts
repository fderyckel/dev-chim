import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("assigned educator submits explicit marks and reads persisted attendance across widths and sessions", async ({
  page,
  context,
}) => {
  await page.goto("/classroom");
  await expect(
    page.getByRole("button", { name: "Start synthetic educator session" }),
  ).toBeEnabled();
  const denied = await page.request.post("/api/v1/classroom-demo/sign-in", {
    data: {},
  });
  expect(denied.status()).toBe(403);
  await page.getByRole("button", { name: "Start synthetic educator session" }).click();
  await page.getByRole("button", { name: "Synthetic class", exact: true }).click();
  await expect(page.getByRole("button", { name: "Submit attendance" })).toBeDisabled();
  await expect(page.getByRole("radio", { checked: true })).toHaveCount(0);
  const cookie = (await context.cookies()).find(
    (item) => item.name === "__Host-chimwemwe-session",
  );
  expect(cookie?.secure).toBe(true);
  expect(cookie?.httpOnly).toBe(true);
  expect(cookie?.sameSite).toBe("Lax");
  for (const width of [1440, 768, 320]) {
    await page.setViewportSize({ width, height: 900 });
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true);
    expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
    await page.screenshot({
      path: `test-results/classroom-${width}.png`,
      fullPage: true,
    });
  }
  const groups = page.getByRole("group");
  await expect(groups).toHaveCount(3);
  await groups.nth(0).getByRole("radio", { name: "Present", exact: true }).focus();
  await page.keyboard.press("Space");
  await groups.nth(1).getByRole("radio", { name: "Absent", exact: true }).check();
  await groups.nth(2).getByRole("radio", { name: "Late", exact: true }).check();
  await page.getByRole("button", { name: "Submit attendance" }).click();
  await expect(page.getByRole("status")).toContainText("Attendance saved");
  await page.reload();
  await page.getByRole("button", { name: "Synthetic class", exact: true }).click();
  await expect(page.getByRole("status")).toContainText("Attendance saved");
  await expect(groups.nth(0)).toContainText("Present");
  await expect(groups.nth(1)).toContainText("Absent");
  await expect(groups.nth(2)).toContainText("Late");
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.screenshot({ path: "test-results/classroom-saved.png", fullPage: true });
  await page.getByRole("button", { name: "Sign out", exact: true }).click();
  await expect(page.getByRole("status")).toHaveText("Signed out.");
  expect((await page.request.get("/api/v1/classroom/classes")).status()).toBe(401);
  await page.getByRole("button", { name: "Start synthetic educator session" }).click();
  await page.getByRole("button", { name: "Synthetic class", exact: true }).click();
  await expect(page.getByRole("status")).toContainText("Attendance saved");
});
