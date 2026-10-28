import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

const primary = (page: Page) =>
  page.getByRole("navigation", { name: "Primary navigation" });
const home = (page: Page) =>
  page.getByRole("region", { name: "Personal Home preview", exact: true });
const appEditor = (page: Page) =>
  page.getByRole("region", { name: "Organize apps", exact: true });
const homeEditor = (page: Page) =>
  page.getByRole("region", { name: "Customize my Home", exact: true });

test("app-group drafts, aliases, canonical search, navigation and scoped reset", async ({
  page,
}, info) => {
  await page.goto(`/demo/apps?demo=${info.project.name}`);
  await page.getByRole("button", { name: "Organize apps", exact: true }).focus();
  await page.getByRole("button", { name: "Organize apps", exact: true }).press("Enter");
  const editor = appEditor(page);
  await expect(
    editor.getByRole("heading", { name: "Organize apps", exact: true }),
  ).toBeFocused();
  await editor.getByLabel("Navigation group 2 name").fill("Planning");
  await editor.getByLabel("Add page to Students & support").selectOption("calendar");
  await editor.getByRole("button", { name: "Preview layout", exact: true }).click();
  await expect(editor.getByRole("region", { name: "Layout preview" })).toContainText(
    "Planning",
  );
  await editor.getByRole("button", { name: "Cancel", exact: true }).click();
  await expect(
    page.getByRole("region", { name: "Teaching & learning", exact: true }),
  ).toBeVisible();
  await expect(page.locator(".c-demo-app-tile")).toHaveCount(3);
  await page.getByRole("button", { name: "Organize apps", exact: true }).click();
  await editor.getByLabel("Navigation group 2 name").fill("Planning");
  await editor.getByLabel("Add page to Students & support").selectOption("calendar");
  await editor.getByRole("button", { name: "Apply layout", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Organize apps", exact: true }),
  ).toBeFocused();
  await expect(
    page.locator(".c-demo-app-tile").filter({ hasText: "Calendar" }),
  ).toHaveCount(2);
  await page.getByRole("searchbox").fill("calendar");
  await expect(page.getByRole("status")).toHaveText("1 page found");
  await page.getByRole("button", { name: "Clear search" }).click();
  await page
    .getByRole("region", { name: "Planning", exact: true })
    .getByRole("link", { name: "Calendar", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { level: 1, name: "Calendar", exact: true }),
  ).toBeVisible();
  await expect(page.getByRole("combobox", { name: "Demo institution" })).toHaveValue(
    info.project.name,
  );
  await page.goBack();
  await expect(
    page.getByRole("region", { name: "Planning", exact: true }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Reset app organization", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toContainText(
    "Personal Home layouts are not reset",
  );
  await page.keyboard.press("Escape");
  await expect(
    page.getByRole("button", { name: "Reset app organization", exact: true }),
  ).toBeFocused();
  await page
    .getByRole("button", { name: "Reset app organization", exact: true })
    .click();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Reset layout", exact: true })
    .click();
  await expect(
    page.getByRole("region", { name: "Teaching & learning", exact: true }),
  ).toBeVisible();
  await expect(page.locator(".c-demo-app-tile")).toHaveCount(3);
});

test("personal Home layouts remain independent and have an explicit starting layout", async ({
  page,
}, info) => {
  await page.goto(`/?demo=${info.project.name}`);
  await home(page)
    .getByRole("button", { name: "Customize my Home", exact: true })
    .focus();
  await home(page)
    .getByRole("button", { name: "Customize my Home", exact: true })
    .press("Enter");
  const editor = homeEditor(page);
  await expect(
    editor.getByRole("heading", { name: "Customize my Home", exact: true }),
  ).toBeFocused();
  await editor.getByLabel("Home section 1 name").fill("Morning");
  await editor.getByRole("button", { name: "Add Home section", exact: true }).click();
  await editor.getByLabel("Home section 2 name").fill("School information");
  const contacts =
    info.project.name === "us-community-college" ? "Contacts" : "Families & guardians";
  await editor
    .getByLabel(`Move ${contacts} to section`)
    .selectOption({ label: "School information" });
  const moved = editor
    .locator(".c-demo-layout-items > li")
    .filter({ hasText: contacts });
  await expect(moved).toBeFocused();
  await expect(editor.getByRole("status")).toContainText("moved to School information");
  await editor.getByRole("button", { name: "Preview layout", exact: true }).click();
  await editor.getByRole("button", { name: "Cancel", exact: true }).click();
  await expect(
    home(page).getByRole("region", { name: "Quick access", exact: true }),
  ).toBeVisible();
  await home(page)
    .getByRole("button", { name: "Customize my Home", exact: true })
    .click();
  await editor.getByLabel("Home section 1 name").fill("Morning");
  await editor.getByRole("button", { name: "Apply layout", exact: true }).click();
  await home(page)
    .getByRole("button", { name: "New Home layout", exact: true })
    .focus();
  await home(page)
    .getByRole("button", { name: "New Home layout", exact: true })
    .press("Enter");
  await expect(
    editor.getByRole("heading", { name: "Customize my Home", exact: true }),
  ).toBeFocused();
  await editor.getByLabel("Layout name", { exact: true }).fill("Planning");
  await editor.getByRole("button", { name: "Apply layout", exact: true }).click();
  await expect(
    home(page).getByRole("button", { name: "Make default", exact: true }),
  ).toBeVisible();
  await home(page).getByRole("button", { name: "Make default", exact: true }).focus();
  await home(page)
    .getByRole("button", { name: "Make default", exact: true })
    .press("Enter");
  await expect(
    home(page).getByRole("combobox", { name: "Home layout", exact: true }),
  ).toBeFocused();
  await primary(page).getByRole("link", { name: "Apps", exact: true }).click();
  await page.getByRole("button", { name: "Organize apps", exact: true }).click();
  await appEditor(page)
    .getByLabel("Navigation group 2 name")
    .fill("Institution planning");
  await appEditor(page)
    .getByRole("button", { name: "Apply layout", exact: true })
    .click();
  await primary(page).getByRole("link", { name: "Home", exact: true }).click();
  await expect(
    home(page).getByRole("combobox", { name: "Home layout", exact: true }),
  ).toHaveValue("home-2");
  await home(page)
    .getByRole("combobox", { name: "Home layout", exact: true })
    .selectOption("home-1");
  await expect(
    home(page).getByRole("region", { name: "Morning", exact: true }),
  ).toBeVisible();
  await home(page)
    .getByRole("button", { name: "Reset Home layout", exact: true })
    .click();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Reset layout", exact: true })
    .click();
  await expect(
    home(page).getByRole("region", { name: "Quick access", exact: true }),
  ).toBeVisible();
  await expect(
    home(page)
      .getByRole("combobox", { name: "Home layout", exact: true })
      .locator("option"),
  ).toHaveCount(2);
  await primary(page).getByRole("link", { name: "Apps", exact: true }).click();
  await expect(
    page.getByRole("region", { name: "Institution planning", exact: true }),
  ).toBeVisible();
});

test("temporary layouts reset on reload, institution change and restored history without storage or writes", async ({
  page,
}, info) => {
  await page.goto(`/demo/apps?demo=${info.project.name}`);
  const writes: string[] = [];
  page.on("request", (request) => {
    if (!["GET", "HEAD"].includes(request.method())) writes.push(request.url());
  });
  await page.getByRole("button", { name: "Organize apps", exact: true }).click();
  await appEditor(page)
    .getByLabel("Navigation group 2 name")
    .fill("Temporary planning");
  await appEditor(page)
    .getByRole("button", { name: "Apply layout", exact: true })
    .click();
  await page.reload();
  await expect(
    page.getByRole("region", { name: "Teaching & learning", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Organize apps", exact: true }).click();
  await appEditor(page)
    .getByLabel("Navigation group 2 name")
    .fill("Another temporary group");
  await appEditor(page)
    .getByRole("button", { name: "Apply layout", exact: true })
    .click();
  const other =
    info.project.name === "us-community-college"
      ? "england-independent"
      : "us-community-college";
  await page.getByRole("combobox", { name: "Demo institution" }).selectOption(other);
  await page.getByRole("button", { name: "Switch", exact: true }).click();
  await expect(
    page.getByRole("region", { name: "Teaching & learning", exact: true }),
  ).toBeVisible();
  await page.goBack();
  await expect(page.getByRole("combobox", { name: "Demo institution" })).toHaveValue(
    info.project.name,
  );
  await expect(
    page.getByRole("region", { name: "Teaching & learning", exact: true }),
  ).toBeVisible();
  expect(
    await page.evaluate(() => ({
      local: localStorage.length,
      session: sessionStorage.length,
    })),
  ).toEqual({ local: 0, session: 0 });
  expect(writes).toEqual([]);
});

test("phone editing, empty-catalogue recovery, validation and movement stay accessible", async ({
  page,
}, info) => {
  await page.setViewportSize({ width: 320, height: 1000 });
  await page.goto(`/demo/apps?demo=${info.project.name}`);
  await page.getByRole("button", { name: "Organize apps", exact: true }).click();
  const editor = appEditor(page);
  await editor
    .getByRole("button", { name: "Remove section", exact: true })
    .first()
    .click();
  await editor.getByRole("button", { name: "Remove section", exact: true }).click();
  await editor.getByRole("button", { name: "Apply layout", exact: true }).click();
  await page.getByText("All available pages", { exact: true }).first().click();
  await expect(
    page
      .getByRole("navigation", { name: "All available pages", exact: true })
      .getByRole("link"),
  ).toHaveCount(4);
  await page.getByRole("button", { name: "Organize apps", exact: true }).click();
  await editor
    .getByRole("button", { name: "Add navigation group", exact: true })
    .click();
  const label = editor.getByLabel("Navigation group 1 name");
  await expect(label).toBeFocused();
  await label.fill("");
  await editor.getByRole("button", { name: "Apply layout", exact: true }).click();
  await expect(editor.getByRole("alert")).toBeVisible();
  await label.fill("Planning and information for the institution");
  await editor
    .getByLabel("Add page to Planning and information for the institution")
    .selectOption("contacts");
  await editor
    .getByLabel("Add page to Planning and information for the institution")
    .selectOption("calendar");
  const calendar = editor
    .locator(".c-demo-layout-items > li")
    .filter({ hasText: "Calendar" });
  await calendar.getByRole("button", { name: "Move up", exact: true }).click();
  await expect(calendar).toBeFocused();
  await expect(editor.getByRole("status")).toContainText("position 1");
  await editor.getByRole("button", { name: "Preview layout", exact: true }).click();
  expect(
    await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
  ).toBe(true);
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await primary(page).getByRole("link", { name: "Apps", exact: true }).focus();
  await primary(page)
    .getByRole("link", { name: "Apps", exact: true })
    .scrollIntoViewIfNeeded();
  await page.screenshot({ path: info.outputPath("editor-phone.png"), fullPage: true });
  await editor.getByRole("button", { name: "Apply layout", exact: true }).click();
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await primary(page).getByRole("link", { name: "Apps", exact: true }).focus();
  await primary(page)
    .getByRole("link", { name: "Apps", exact: true })
    .scrollIntoViewIfNeeded();
  await page.screenshot({ path: info.outputPath("applied-phone.png"), fullPage: true });
});
