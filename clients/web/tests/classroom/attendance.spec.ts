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

test("administrator prepares a class and student before the educator opens attendance", async ({
  page,
}) => {
  await page.goto("/classroom/setup");
  await page
    .getByRole("button", { name: "Start synthetic administrator session" })
    .click();
  await expect(
    page.getByRole("heading", { name: "Synthetic Learning Institution" }),
  ).toBeVisible();

  const missingCsrf = await page.request.post("/api/v1/classroom/prepare-class", {
    data: {
      code: "forbidden_class",
      label: "Forbidden class",
      idempotency_key: crypto.randomUUID(),
      causation_id: crypto.randomUUID(),
    },
    headers: { Origin: "https://localhost:3013" },
  });
  expect(missingCsrf.status()).toBe(403);

  await page.getByRole("button", { name: "Create class and assign educator" }).click();
  await expect(page.getByRole("status")).toContainText(
    "Class and educator assignment saved together",
  );
  await expect(page.getByRole("heading", { name: "Year 6 Blue" })).toBeVisible();

  await page.getByLabel("Student display name").fill("Synthetic Learner D");
  await page.getByRole("button", { name: "Add student to class" }).click();
  await expect(page.getByRole("status")).toContainText(
    "Student, enrolment, and class placement saved together",
  );
  await expect(page.getByRole("list", { name: "Prepared students" })).toContainText(
    "Synthetic Learner D",
  );

  await page.setViewportSize({ width: 320, height: 900 });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.screenshot({
    path: "test-results/classroom-preparation.png",
    fullPage: true,
  });

  await page.getByRole("link", { name: "Open today’s attendance" }).click();
  await page.getByRole("button", { name: "Year 6 Blue", exact: true }).click();
  await expect(page.getByRole("group")).toHaveCount(1);
  await expect(page.getByRole("group")).toContainText("Synthetic Learner D");
  await page.getByRole("radio", { name: "Present", exact: true }).check();
  await page.getByRole("button", { name: "Submit attendance" }).click();
  await expect(page.getByRole("status")).toContainText("Attendance saved");

  await page.goto("/classroom/setup");
  await expect(page.getByRole("heading", { name: "Year 6 Blue" })).toBeVisible();
  await expect(page.getByRole("list", { name: "Prepared students" })).toContainText(
    "Synthetic Learner D",
  );
});
