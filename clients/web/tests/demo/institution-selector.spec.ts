import { expect, test } from "@playwright/test";

const institutions = [
  ["bangkok-international", "Lotus Grove International School (Demo)", 112],
  ["us-community-college", "Cedar Coast Community College (Demo)", 97],
  ["hong-kong-kindergarten", "Harbour Lantern Kindergarten (Demo)", 72],
  ["england-independent", "Alder Mere School (Demo)", 84],
] as const;

test("switches all four institutions in the same tab and retains the choice across sections, refresh and back", async ({
  page,
}) => {
  await page.goto("/demo/students");
  const origin = new URL(page.url()).origin;
  const selector = page.getByRole("combobox", {
    name: "Demo institution",
    exact: true,
  });
  await expect(selector.locator("option")).toHaveCount(4);
  await page.getByRole("searchbox").fill("impossible-name-zz");
  for (const [slug, name, count] of institutions) {
    const currentName = await page.locator(".c-context-summary__name").innerText();
    await selector.selectOption(slug);
    await expect(page.getByText(currentName, { exact: true })).toBeVisible();
    await page.getByRole("button", { name: "Switch", exact: true }).click();
    await expect(page.getByText(name, { exact: true })).toBeVisible();
    await expect(selector).toHaveValue(slug);
    await expect(page.getByRole("searchbox")).toHaveValue("");
    await expect(page.locator("details[open]")).toHaveCount(0);
    await expect(page.getByRole("status")).toHaveText(`1–12 of ${count} students`);
    expect(new URL(page.url()).origin).toBe(origin);
    expect(new URL(page.url()).pathname).toBe("/demo/students");
    expect(new URL(page.url()).searchParams.get("demo")).toBe(slug);
    for (const [otherSlug, otherName] of institutions)
      if (otherSlug !== slug)
        await expect(page.getByText(otherName, { exact: true })).toHaveCount(0);
    await page.locator("summary").first().click();
    await page.getByRole("searchbox").fill("S001");
  }
  const nav = page.getByRole("navigation", { name: "Primary navigation" });
  for (const title of ["Families & guardians", "Educators", "Calendar"]) {
    await nav.getByRole("link", { name: title, exact: true }).click();
    await expect(
      page.getByRole("heading", { level: 1, name: title, exact: true }),
    ).toBeVisible();
    await expect(selector).toHaveValue("england-independent");
  }
  await page.getByRole("button", { name: "Next month", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "November 2026", exact: true }),
  ).toBeVisible();
  await selector.selectOption("us-community-college");
  await page.getByRole("button", { name: "Switch", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "October 2026", exact: true }),
  ).toBeVisible();
  await expect(page.getByText(institutions[1][1], { exact: true })).toBeVisible();
  await expect(nav.getByRole("link", { name: "Contacts", exact: true })).toBeVisible();
  await expect(
    nav.getByRole("link", { name: "Instructors", exact: true }),
  ).toBeVisible();
  await page.reload();
  await expect(selector).toHaveValue("us-community-college");
  await page.goBack();
  await expect(selector).toHaveValue("england-independent");
  await expect(page.getByText(institutions[3][1], { exact: true })).toBeVisible();
  await selector.selectOption("bangkok-international");
  await selector.focus();
  await page.keyboard.press("Tab");
  await expect(page.getByRole("button", { name: "Switch", exact: true })).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.getByText(institutions[0][1], { exact: true })).toBeVisible();
});

test("invalid and repeated demo selections fail closed and allow recovery", async ({
  page,
  request,
}) => {
  for (const query of [
    "demo=unknown",
    "demo=..%2Fpacks%2Fengland-independent.json",
    "demo=england-independent&demo=us-community-college",
  ]) {
    await page.goto(`/demo/students?${query}`);
    await expect(
      page.getByRole("heading", { name: "Demo unavailable", exact: true }),
    ).toBeVisible();
    for (const [, name] of institutions)
      await expect(page.getByText(name, { exact: true })).toHaveCount(0);
  }
  await page.getByRole("link", { name: "Return to demo", exact: true }).click();
  await expect(
    page.getByRole("combobox", { name: "Demo institution", exact: true }),
  ).toBeVisible();
  const denied = await request.get("/demo?demo=england-independent", {
    headers: { Host: "school.example" },
  });
  expect(await denied.text()).toContain("Demo unavailable");
});
