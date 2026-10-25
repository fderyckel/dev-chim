import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

test("Home, Apps and workspaces retain the selected institution and only expose working destinations", async ({
  page,
  request,
}, info) => {
  const slug = info.project.name;
  const college = slug === "us-community-college";
  await page.goto(`/?demo=${slug}`);
  await expect(page.getByRole("heading", { name: "Home", exact: true })).toBeVisible();
  await page.getByRole("link", { name: "Browse apps", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/demo/apps\\?demo=${slug}$`));
  await expect(page.locator(".c-demo-app-tile")).toHaveCount(3);
  await expect(
    page.getByText(college ? "Students and contacts" : "Students and family contacts", {
      exact: true,
    }),
  ).toBeVisible();
  await expect(
    page.getByRole("link", {
      name: college ? "Instructors" : "Educators",
      exact: true,
    }),
  ).toBeVisible();
  const search = page.getByRole("searchbox", { name: "Find an app or page" });
  await search.fill("family contacts");
  await expect(page.getByRole("status")).toHaveText("1 page found");
  await page
    .getByRole("main")
    .getByRole("link", {
      name: college ? "Contacts Students" : "Families & guardians Students",
      exact: true,
    })
    .click();
  await expect(page).toHaveURL(new RegExp(`/demo/contacts\\?demo=${slug}$`));
  await expect(
    page.getByRole("navigation", { name: "Workspace navigation" }).getByRole("link", {
      name: college ? "Contacts" : "Families & guardians",
      exact: true,
    }),
  ).toHaveAttribute("aria-current", "page");
  await expect(page.getByText(/Contact links only/)).toBeVisible();
  await page.goBack();
  await expect(page.getByRole("heading", { name: "Apps", exact: true })).toBeVisible();
  await search.fill("S001");
  await expect(page.getByRole("status")).toHaveText(
    "No apps or pages match your search.",
  );
  await page.getByRole("button", { name: "Clear search" }).click();
  await expect(page.locator(".c-demo-app-tile")).toHaveCount(3);
  await page.reload();
  await expect(page.getByRole("combobox", { name: "Demo institution" })).toHaveValue(
    slug,
  );
  const unavailable = await request.get(`/demo/admissions?demo=${slug}`);
  expect(unavailable.status()).toBe(404);
  await page.goto("/demo/apps?demo=unknown");
  await expect(
    page.getByRole("heading", { name: "Demo unavailable", exact: true }),
  ).toBeVisible();
  await expect(page.locator(".c-demo-app-tile")).toHaveCount(0);
});

test("phone navigation and app discovery reflow with keyboard access", async ({
  page,
}, info) => {
  for (const width of [1440, 768, 320]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto("/demo/apps");
    await expect(page.locator(".c-demo-app-tile")).toHaveCount(3);
    expect(
      await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
    ).toBe(true);
    expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
    await page.screenshot({
      path: info.outputPath(`apps-${width}.png`),
      fullPage: true,
    });
    await page
      .getByRole("main")
      .getByRole("link", { name: "Students", exact: true })
      .click();
    if (width <= 992) {
      const disclosure = page.locator(".c-demo-workspace-mobile");
      const summary = disclosure.locator("summary");
      await summary.focus();
      await page.keyboard.press("Enter");
      await expect(disclosure).toHaveAttribute("open", "");
      await page.keyboard.press("Tab");
      await expect(
        page
          .getByRole("navigation", { name: "Workspace navigation" })
          .getByRole("link", { name: "Students", exact: true }),
      ).toBeFocused();
      const contacts = page
        .getByRole("navigation", { name: "Workspace navigation" })
        .getByRole("link")
        .nth(1);
      await contacts.click();
      await expect(page.locator(".c-demo-workspace-mobile")).not.toHaveAttribute(
        "open",
        "",
      );
      await expect(page.locator(".c-demo-workspace-mobile > summary")).toContainText(
        info.project.name === "us-community-college"
          ? "Contacts"
          : "Families & guardians",
      );
      await page.locator(".c-demo-workspace-mobile > summary").click();
      await page.keyboard.press("Space");
      await expect(page.locator(".c-demo-workspace-mobile")).not.toHaveAttribute(
        "open",
        "",
      );
    }
    expect(
      await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
    ).toBe(true);
    expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
    await page.screenshot({
      path: info.outputPath(`workspace-${width}.png`),
      fullPage: true,
    });
  }
});

test("switching on Apps preserves the page, resets search and restores context through history", async ({
  page,
}) => {
  await page.goto("/demo/apps?demo=england-independent");
  await page.getByRole("searchbox").fill("families");
  const choice = page.getByRole("combobox", { name: "Demo institution" });
  await choice.selectOption("us-community-college");
  await page.getByRole("button", { name: "Switch", exact: true }).click();
  await expect(page).toHaveURL(/\/demo\/apps\?demo=us-community-college$/);
  await expect(page.getByRole("searchbox")).toHaveValue("");
  await expect(
    page.getByRole("link", { name: "Instructors", exact: true }),
  ).toBeVisible();
  await page.goBack();
  await expect(choice).toHaveValue("england-independent");
  await expect(
    page.getByRole("link", { name: "Educators", exact: true }),
  ).toBeVisible();
  await page.goForward();
  await expect(choice).toHaveValue("us-community-college");
});

test("an unsubmitted choice does not replace the institution when opening an app", async ({
  page,
}) => {
  await page.goto("/demo/apps?demo=england-independent");
  const choice = page.getByRole("combobox", { name: "Demo institution" });
  await choice.selectOption("us-community-college");
  await page
    .getByRole("main")
    .getByRole("link", { name: "Calendar", exact: true })
    .click();
  await expect(page).toHaveURL(/\/demo\/calendar\?demo=england-independent$/);
  await expect(choice).toHaveValue("england-independent");
  await page.goBack();
  await expect(page.getByRole("heading", { name: "Apps", exact: true })).toBeVisible();
  await expect(choice).toHaveValue("england-independent");
  await page.goForward();
  await expect(choice).toHaveValue("england-independent");
});
