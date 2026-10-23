import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

const names: Record<string, string> = {
  "bangkok-international": "Lotus Grove International School (Demo)",
  "us-community-college": "Cedar Coast Community College (Demo)",
  "hong-kong-kindergarten": "Harbour Lantern Kindergarten (Demo)",
  "england-independent": "Alder Mere School (Demo)",
};

test("selected institution loads its people, relationships and calendar", async ({
  page,
  request,
}, info) => {
  const college = info.project.name === "us-community-college";
  await page.goto("/");
  await expect(page.getByText(names[info.project.name], { exact: true })).toBeVisible();
  await expect(page.getByText(/As of 23 Oct 2026/).first()).toBeVisible();
  await expect(page.getByText("Local demo · fictional data · read only")).toBeVisible();
  for (const [slug, name] of Object.entries(names))
    if (slug !== info.project.name)
      await expect(page.getByText(name, { exact: true })).toHaveCount(0);
  await page
    .getByRole("navigation", { name: "Primary navigation" })
    .getByRole("link", { name: "Students", exact: true })
    .click();
  await expect(
    page.getByRole("status").filter({ hasText: /of \d+ students/ }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Next", exact: true }).click();
  await expect(page.getByRole("status").filter({ hasText: /13–24/ })).toBeVisible();
  const search = page.getByRole("searchbox", { name: "Search students" });
  await search.fill("S003");
  await page.locator("summary").first().click();
  await expect(page.getByText("Starts later", { exact: true }).first()).toBeVisible();
  await expect(
    page.getByRole("heading", {
      name: college ? "Course sections" : "Daily register",
      exact: true,
    }),
  ).toBeVisible();
  await search.fill("S004");
  await expect(page.getByText("Ended", { exact: true }).first()).toBeVisible();
  await search.fill("impossible-name-zz");
  await expect(page.getByRole("status")).toContainText("No students match");
  await search.fill("S001");
  // Each filtered record is a new keyed details element; open explicitly if needed.
  await page.locator("summary").first().click();
  await expect(page.getByText(/Contact links do not grant/)).toBeVisible();
  await page
    .getByRole("navigation", { name: "Primary navigation" })
    .getByRole("link", {
      name: college ? "Contacts" : "Families & guardians",
      exact: true,
    })
    .click();
  await page.locator("summary").first().click();
  await expect(page.getByRole("heading", { name: "Linked students" })).toBeVisible();
  await page
    .getByRole("navigation", { name: "Primary navigation" })
    .getByRole("link", { name: college ? "Instructors" : "Educators", exact: true })
    .click();
  await page.locator("summary").first().click();
  await expect(
    page.getByRole("heading", {
      name: college ? "Course sections" : "Register responsibilities",
      exact: true,
    }),
  ).toBeVisible();
  await page
    .getByRole("navigation", { name: "Primary navigation" })
    .getByRole("link", { name: "Calendar", exact: true })
    .click();
  for (const heading of ["Teaching periods", "Student closures", "Events"])
    await expect(
      page.getByRole("heading", { name: heading, exact: true }),
    ).toBeVisible();
  await expect(page.getByText("Events do not change teaching days.")).toBeVisible();
  await page.goto("/demo/students?institution=other&tenant_id=other");
  await expect(page.getByText(names[info.project.name], { exact: true })).toBeVisible();
  const denied = await request.get("/demo", { headers: { Host: "school.example" } });
  const deniedBody = await denied.text();
  expect(deniedBody).toContain("Demo unavailable");
  expect(deniedBody).not.toContain(names[info.project.name]);
});

test("demo navigation, keyboard and reflow stay accessible across screen sizes", async ({
  page,
}, info) => {
  await page.goto("/demo/students");
  await page.keyboard.press("Tab");
  await expect(page.getByRole("link", { name: "Skip to main content" })).toBeFocused();
  await page.getByRole("searchbox").focus();
  await page.keyboard.press("Tab");
  if (info.project.name !== "us-community-college") await page.keyboard.press("Tab");
  await expect(page.locator("summary").first()).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("details").first()).toHaveAttribute("open", "");
  for (const width of [1440, 768, 320]) {
    await page.setViewportSize({ width, height: 1000 });
    await expect(
      page.getByRole("link", { name: "Calendar", exact: true }),
    ).toBeVisible();
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true);
    const violations = (await new AxeBuilder({ page }).analyze()).violations;
    expect(violations).toEqual([]);
    await page.screenshot({
      path: info.outputPath(`students-${width}.png`),
      fullPage: true,
    });
  }
});
