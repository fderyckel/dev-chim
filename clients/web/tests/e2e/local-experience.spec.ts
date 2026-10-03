import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

const previewProfiles = [
  { id: "light", label: "Quiet light" },
  { id: "dark", label: "Calm dark" },
  { id: "readable", label: "Clear reading" },
] as const;

async function chooseProfile(page: Page, label: string) {
  const radio = page.getByRole("radio", { name: new RegExp(label) });
  await radio.focus();
  await page.keyboard.press("Space");
  await expect(radio).toBeChecked();

  const profileId = await radio.getAttribute("value");
  if (profileId === "light") {
    await expect(page.locator("html")).not.toHaveAttribute("data-theme");
  } else {
    await expect(page.locator("html")).toHaveAttribute("data-theme", profileId ?? "");
  }
}

test("home clearly identifies its synthetic context and primary next step", async ({
  page,
}) => {
  await page.goto("/");

  await expect(
    page.getByRole("heading", { level: 1, name: "A clear place to begin" }),
  ).toBeVisible();
  await expect(page.getByText("Local prototype · synthetic data")).toBeVisible();
  await expect(page.getByText("Synthetic tenant")).toBeVisible();
  await expect(page.getByText("Local fixture · no server connection")).toBeVisible();
  await expect(
    page.getByRole("link", { name: "Review attention items" }),
  ).toBeVisible();
});

test("keyboard navigation reaches the preview and its recovery language", async ({
  page,
}) => {
  await page.goto("/");

  const skipLink = page.getByRole("link", { name: "Skip to main content" });
  await page.keyboard.press("Tab");
  await expect(skipLink).toBeFocused();

  const previewLink = page.getByRole("link", { name: "UI preview" });
  for (let attempt = 0; attempt < 6; attempt += 1) {
    await page.keyboard.press("Tab");
    if (await previewLink.evaluate((element) => element === document.activeElement))
      break;
  }
  await expect(previewLink).toBeFocused();
  await page.keyboard.press("Enter");

  await expect(
    page.getByRole("heading", { level: 1, name: "UI preview" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Access unavailable" }).click();
  await expect(page.getByRole("status").last()).toContainText(
    "You do not have access to this view",
  );
  await expect(page.getByRole("status").last()).toContainText("What to do:");
});

test("the structure prototype separates linked meanings and blocks unknown impacts", async ({
  page,
}) => {
  await page.goto("/institutional-structure");

  await expect(
    page.getByRole("heading", { level: 1, name: "Institutional structure" }),
  ).toBeVisible();
  await expect(
    page.getByRole("list", { name: "Institutional containment" }),
  ).toBeVisible();
  await expect(page.getByText("Separate structures")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Legal entities" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Corporate units" })).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Legal responsibility" }),
  ).toBeVisible();
  await expect(page.getByText("Primary legal operator")).toBeVisible();
  await expect(page.getByText(/Consolidation is not ownership/)).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Transfer review path" }),
  ).toBeVisible();
  await expect(page.getByText("Governed single-controller exception")).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Five representative contexts" }),
  ).toBeVisible();
  const institutionalTree = page.getByRole("list", {
    name: "Institutional containment",
  });
  for (const contextLabel of [
    "Primary / early years · NPES",
    "Secondary school · CSS",
    "Combined formal education · MCS",
    "College / community college · LCC",
    "University · MU",
  ]) {
    await expect(
      institutionalTree.getByText(contextLabel, { exact: true }),
    ).toBeVisible();
  }
  await expect(page.getByRole("heading", { name: "Sites" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Affiliations" })).toBeVisible();
  await expect(page.getByText("Blocks move")).toBeVisible();
  await expect(page.getByText("Blocks transfer")).toBeVisible();
  await expect(page.getByText("Ready for boundary check")).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Legal accountability under review" }),
  ).toBeVisible();
  const accountabilityReview = page.getByRole("region", {
    name: "Legal accountability under review",
  });
  await expect(
    accountabilityReview.getByText("Unavailable", { exact: true }),
  ).toHaveCount(2);
  await expect(page.getByRole("button")).toHaveCount(0);
});

test("local prototype pages reflow without page-level horizontal scrolling", async ({
  page,
}) => {
  for (const path of ["/", "/institutional-structure", "/ui-preview"]) {
    await page.goto(path);
    const widths = await page.evaluate(() => ({
      viewport: window.innerWidth,
      document: document.documentElement.scrollWidth,
    }));

    expect(
      widths.document,
      `${path} should reflow within the viewport`,
    ).toBeLessThanOrEqual(widths.viewport);
  }
});

test("local prototype pages have no automatically detectable accessibility violations", async ({
  page,
}) => {
  for (const path of ["/", "/institutional-structure", "/ui-preview"]) {
    await page.goto(path);
    const result = await new AxeBuilder({ page }).analyze();

    expect(result.violations, `${path} accessibility violations`).toEqual([]);
  }
});

test("experience profiles preview locally, reset explicitly, and never persist", async ({
  page,
}) => {
  await page.goto("/ui-preview");

  const root = page.locator("html");
  await expect(root).not.toHaveAttribute("data-theme");
  await expect(page.getByRole("radio", { name: /Quiet light/ })).toBeChecked();

  await chooseProfile(page, "Calm dark");
  await expect(root).toHaveAttribute("data-theme", "dark");
  await expect(page.getByRole("status").filter({ hasText: "Calm dark" })).toContainText(
    "not saved",
  );

  await chooseProfile(page, "Clear reading");
  await expect(root).toHaveAttribute("data-theme", "readable");
  await expect(
    page.getByRole("status").filter({ hasText: "Clear reading" }),
  ).toContainText("not saved");

  await page.getByRole("button", { name: "Reset to Chimwemwe default" }).click();
  await expect(root).not.toHaveAttribute("data-theme");
  await expect(page.getByRole("radio", { name: /Quiet light/ })).toBeChecked();

  const storage = await page.evaluate(() => ({
    local: window.localStorage.length,
    session: window.sessionStorage.length,
  }));
  expect(storage).toEqual({ local: 0, session: 0 });
  expect(await page.context().cookies()).toEqual([]);

  await chooseProfile(page, "Calm dark");
  await page.getByRole("link", { name: "Return to Home" }).first().click();
  await expect(root).not.toHaveAttribute("data-theme");
});

test("every governed profile keeps the living specimen accessible", async ({
  page,
}) => {
  await page.goto("/ui-preview");

  for (const profile of previewProfiles) {
    await chooseProfile(page, profile.label);
    const result = await new AxeBuilder({ page }).analyze();

    expect(result.violations, `${profile.label} accessibility violations`).toEqual([]);
  }
});

test("every governed profile reflows at the 320 CSS-pixel zoom equivalent", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto("/ui-preview");

  for (const profile of previewProfiles) {
    await chooseProfile(page, profile.label);
    const widths = await page.evaluate(() => ({
      viewport: window.innerWidth,
      document: document.documentElement.scrollWidth,
    }));

    expect(
      widths.document,
      `${profile.label} should reflow at 320 CSS pixels`,
    ).toBeLessThanOrEqual(widths.viewport);
  }
});

test("platform forced-colour and reduced-motion preferences outrank profiles", async ({
  page,
}) => {
  await page.emulateMedia({ forcedColors: "active", reducedMotion: "reduce" });
  await page.goto("/ui-preview");
  await chooseProfile(page, "Calm dark");
  await page.getByRole("button", { name: "Loading" }).click();

  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await expect(page.locator(".c-profile-option").first()).toHaveCSS(
    "border-top-style",
    "solid",
  );

  const motion = await page.locator(".c-spinner").evaluate((element) => {
    const style = getComputedStyle(element);
    return {
      animationDuration: style.animationDuration,
      transitionDuration: style.transitionDuration,
    };
  });
  expect(Number.parseFloat(motion.animationDuration)).toBeLessThanOrEqual(0.00001);
  expect(Number.parseFloat(motion.transitionDuration)).toBeLessThanOrEqual(0.00001);
});

test.describe("default first paint without client JavaScript", () => {
  test.use({ javaScriptEnabled: false });

  test("renders the complete default profile before hydration", async ({ page }) => {
    await page.goto("/ui-preview");

    await expect(
      page.getByRole("heading", { level: 1, name: "UI preview" }),
    ).toBeVisible();
    await expect(page.locator("html")).not.toHaveAttribute("data-theme");
    await expect(page.locator("body")).toHaveCSS(
      "background-color",
      "rgb(247, 247, 241)",
    );
  });
});
