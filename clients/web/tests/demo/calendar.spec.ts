import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

test("Month and Agenda retain context, expose exact details and reflow accessibly", async ({
  page,
}, info) => {
  await page.goto("/demo/calendar");
  await expect(
    page.getByRole("heading", { name: "October 2026", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Month", exact: true }),
  ).toHaveAttribute("aria-pressed", "true");
  await page.getByRole("button", { name: "Next month" }).click();
  await expect(page.getByRole("region", { name: "Ongoing date ranges" })).toContainText(
    "Continues from",
  );
  await page.getByLabel("Jump to date").fill("2026-11-20");
  const day = page.getByRole("region", { name: "Selected day", exact: true });
  const event = day.getByRole("button", { name: /Demo staff learning day/ });
  await event.focus();
  await page.keyboard.press("Enter");
  await expect(page.getByRole("region", { name: "Entry details" })).toContainText(
    "staff",
  );
  await expect(
    page.getByRole("region", { name: "Entry details" }).getByRole("heading"),
  ).toBeFocused();
  await page.getByRole("button", { name: "Close details" }).click();
  await expect(event).toBeFocused();
  if (info.project.name === "us-community-college") {
    await expect(day).toContainText("Student closure");
    await expect(day).toContainText("no instruction");
    await page.getByLabel("Jump to date").fill("2026-09-07");
    const deadlines = day.getByRole("button", {
      name: /Demo session add\/drop deadline/,
    });
    await expect(deadlines).toHaveCount(2);
    expect(await deadlines.nth(0).textContent()).not.toBe(
      await deadlines.nth(1).textContent(),
    );
    await page.getByLabel("Jump to date").fill("2026-11-20");
  }
  await page.getByLabel("Show").selectOption("Event · information only");
  await page.getByRole("tab", { name: "List", exact: true }).click();
  await expect(page.getByRole("table")).toContainText("Demo staff learning day");
  await page.getByRole("tab", { name: "Calendar", exact: true }).click();
  await expect(page.getByLabel("Show")).toHaveValue("Event · information only");
  await expect(page.getByLabel("Jump to date")).toHaveValue("2026-11-20");
  await page.getByLabel("Show").selectOption("");
  for (const width of [1440, 768, 320]) {
    await page.setViewportSize({ width, height: 1000 });
    await expect(
      page.getByRole("button", {
        name: width === 320 ? "Agenda" : "Month",
        exact: true,
      }),
    ).toHaveAttribute("aria-pressed", "true");
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true);
    expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
    await page.screenshot({
      path: info.outputPath(`calendar-${width}.png`),
      fullPage: true,
    });
  }
  await page.getByRole("button", { name: "Month", exact: true }).click();
  await page.setViewportSize({ width: 768, height: 1000 });
  await page.setViewportSize({ width: 320, height: 1000 });
  await expect(
    page.getByRole("button", { name: "Month", exact: true }),
  ).toHaveAttribute("aria-pressed", "true");
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.screenshot({
    path: info.outputPath("calendar-month-320.png"),
    fullPage: true,
  });
  await page.getByRole("button", { name: "Example date", exact: true }).click();
  await expect(page.getByLabel("Jump to date")).toHaveValue("2026-10-23");
});

test("all-day dates stay fixed across browser zones and daylight saving", async ({
  browser,
}, info) => {
  for (const timezoneId of ["America/Los_Angeles", "Pacific/Auckland"]) {
    const context = await browser.newContext({
      baseURL: String(info.project.use.baseURL),
      timezoneId,
    });
    try {
      const page = await context.newPage();
      await page.goto("/demo/calendar");
      for (const date of ["2026-11-01", "2026-11-20"]) {
        await page.getByLabel("Jump to date").fill(date);
        await expect(page.getByLabel("Jump to date")).toHaveValue(date);
        await expect(
          page.getByRole("heading", { name: "November 2026", exact: true }),
        ).toBeVisible();
      }
      await expect(page.getByRole("region", { name: "Selected day" })).toContainText(
        "Demo staff learning day",
      );
    } finally {
      await context.close();
    }
  }
});
