import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { readFile } from "node:fs/promises";

test.afterEach(async ({ page }) => {
  // Failure context must not retain a one-time password or a populated credential form.
  await page
    .evaluate(() => {
      document
        .querySelectorAll('[data-testid="temporary-password"]')
        .forEach((node) => node.remove());
      document
        .querySelectorAll<HTMLInputElement>(
          'input[name="password"], input[name="confirmation"]',
        )
        .forEach((input) => {
          input.value = "";
        });
    })
    .catch(() => {});
});

async function signIn(page: Page, email: string, password: string) {
  await page.goto("/sign-in");
  await page.setViewportSize({ width: 320, height: 900 });
  await expect(
    page.getByRole("button", { name: "Sign in", exact: true }),
  ).toBeEnabled();
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.screenshot({ path: "test-results/staff-sign-in-320.png", fullPage: true });
  await page.getByLabel("Email", { exact: true }).fill(email);
  await page.getByLabel("Password", { exact: true }).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
}

async function protectedBack(page: Page) {
  try {
    await page.goBack({ waitUntil: "commit" });
  } catch (error) {
    // The application immediately reloads a restored protected document to re-authorize it.
    // The safe URL and record state are still asserted after this expected browser cancellation.
    if (!(error instanceof Error) || !error.message.includes("net::ERR_ABORTED"))
      throw error;
  }
}

test("staff account provision, first password, classroom access and institutional suspension use the current server session", async ({
  page,
  context,
  browser,
}) => {
  const credentialFile = process.env.CHIMWEMWE_STAFF_CREDENTIAL_FILE;
  if (!credentialFile) throw new Error("Private bootstrap credential file is required");
  const bootstrap = JSON.parse(await readFile(credentialFile, "utf8")) as {
    email: string;
    password: string;
  };

  await page.goto("/accounts");
  await expect(
    page.getByText("Contact your account administrator if you need access."),
  ).toBeVisible();
  expect((await page.request.get("/api/v1/staff-accounts")).status()).toBe(401);
  expect(
    (await page.request.post("/api/v1/classroom-demo/sign-in", { data: {} })).status(),
  ).toBe(404);

  await page.goto("/sign-in");
  await expect(page.getByLabel("Email", { exact: true })).toHaveAttribute(
    "autocomplete",
    "username",
  );
  await expect(page.getByLabel("Password", { exact: true })).toHaveAttribute(
    "autocomplete",
    "current-password",
  );
  await page.setViewportSize({ width: 320, height: 900 });
  await expect(
    page.getByRole("button", { name: "Sign in", exact: true }),
  ).toBeEnabled();
  await page.screenshot({ path: "test-results/staff-sign-in-320.png", fullPage: true });
  await page
    .getByRole("combobox", { name: "System language", exact: true })
    .selectOption("fr");
  await expect(
    page.getByRole("heading", { name: "Se connecter", exact: true }),
  ).toBeVisible();
  await page
    .getByLabel("Adresse e-mail", { exact: true })
    .fill("unlisted@northstar-school.test");
  await page
    .getByLabel("Mot de passe", { exact: true })
    .fill("Unlisted fictional sign-in phrase 72");
  await page.getByRole("button", { name: "Se connecter", exact: true }).click();
  await expect(page.getByRole("status")).toHaveText(
    "La connexion a échoué. Vérifiez vos identifiants ou contactez l’administrateur de votre compte.",
  );
  await page
    .getByRole("combobox", { name: "Langue du système", exact: true })
    .selectOption("en");
  await page.getByLabel("Email", { exact: true }).fill(bootstrap.email);
  await page.getByLabel("Password", { exact: true }).fill(bootstrap.password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page).toHaveURL(/\/accounts(?:\?|$)/);
  await expect(
    page.getByRole("heading", { name: "Staff accounts", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Signed in as Synthetic Account Administrator", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "New staff account", exact: true }),
  ).toBeInViewport();
  await page.getByRole("button", { name: "New staff account", exact: true }).click();
  await expect(
    page.getByRole("combobox", { name: "Staff member", exact: true }),
  ).toBeFocused();
  const cookie = (await context.cookies()).find(
    (item) => item.name === "__Host-chimwemwe-session",
  );
  expect(cookie?.secure).toBe(true);
  expect(cookie?.httpOnly).toBe(true);
  expect(cookie?.sameSite).toBe("Lax");
  const accountsResponse = await page.request.get("/api/v1/staff-accounts");
  expect(accountsResponse.headers()["cache-control"]).toContain("no-store");
  const inventory = (await accountsResponse.json()).data as {
    eligible_staff: { association_id: string; display_name: string }[];
  };
  const teacher = inventory.eligible_staff.find(
    (person) => person.display_name === "Synthetic Teacher",
  );
  if (!teacher) throw new Error("Synthetic teacher candidate is required");

  for (const width of [1440, 768, 320]) {
    await page.setViewportSize({ width, height: 900 });
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true);
    expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
    await page.screenshot({
      path: `test-results/staff-directory-${width}.png`,
      fullPage: true,
    });
  }

  await page
    .getByRole("combobox", { name: "Staff member", exact: true })
    .selectOption(teacher.association_id);
  await page.getByRole("button", { name: "Cancel", exact: true }).click();
  await expect(
    page.getByRole("combobox", { name: "Staff member", exact: true }),
  ).toHaveValue("");
  await page
    .getByRole("combobox", { name: "Staff member", exact: true })
    .selectOption(teacher.association_id);
  await page
    .getByLabel("Sign-in email", { exact: true })
    .fill("teacher-directory@northstar-school.test");
  await page.getByLabel("I checked this staff identity and sign-in email.").check();
  await page.getByRole("button", { name: "Create staff account", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Temporary password generated", exact: true }),
  ).toBeVisible();
  let temporaryPassword = await page.getByTestId("temporary-password").textContent();
  if (!temporaryPassword)
    throw new Error("One-time temporary password was not returned");
  const storedValues = await page.evaluate(() => ({
    local: Object.keys(localStorage),
    session: Object.keys(sessionStorage),
  }));
  expect(storedValues).toEqual({ local: [], session: [] });
  await page.getByRole("button", { name: "Dismiss temporary password" }).click();
  await page.getByRole("link", { name: "Synthetic Teacher", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Synthetic Teacher", exact: true }),
  ).toBeVisible();
  await expect(page.getByTestId("temporary-password")).toHaveCount(0);
  await page
    .getByRole("combobox", { name: "Access profile", exact: true })
    .selectOption({ label: "Classroom teacher" });
  await page.getByRole("button", { name: "Add access profile", exact: true }).click();
  await expect(page.locator("#staff-directory-status")).toHaveText(
    "Access profile added.",
  );
  await page.getByRole("button", { name: "About access profiles" }).focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#staff-access-help")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.locator("#staff-access-help")).toHaveCount(0);
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  await page.screenshot({ path: "test-results/staff-account-320.png", fullPage: true });
  await page
    .getByLabel("I verified the recipient and can deliver the password privately.")
    .check();
  await page
    .getByRole("button", { name: "New temporary password", exact: true })
    .click();
  await expect(page.locator("#temporary-password-title span")).toBeFocused();
  expect(
    await page
      .locator("#temporary-password-title")
      .evaluate(
        (node) =>
          node.getBoundingClientRect().top >= 0 &&
          node.getBoundingClientRect().bottom <= innerHeight,
      ),
  ).toBe(true);
  await expect(
    page.getByText(
      "Shown once. Deliver privately after verifying the recipient’s identity.",
    ),
  ).toBeVisible();
  temporaryPassword = await page.getByTestId("temporary-password").textContent();
  if (!temporaryPassword)
    throw new Error("Reissued one-time temporary password was not returned");
  await page.getByRole("button", { name: "Dismiss temporary password" }).click();
  await page.reload();
  await expect(page.getByTestId("temporary-password")).toHaveCount(0);

  const staffContext = await browser.newContext({
    baseURL: "https://localhost:3015",
    ignoreHTTPSErrors: true,
  });
  const staff = await staffContext.newPage();
  try {
    await signIn(staff, "teacher-directory@northstar-school.test", temporaryPassword);
    await expect(staff).toHaveURL(/\/first-login\/password/);
    expect((await staff.request.get("/api/v1/session")).status()).toBe(401);
    expect((await staff.request.get("/api/v1/staff-accounts")).status()).toBe(401);
    await staff
      .getByRole("button", { name: "Cancel and return to sign-in", exact: true })
      .click();
    await expect(staff).toHaveURL(/\/sign-in/);
    await signIn(staff, "teacher-directory@northstar-school.test", temporaryPassword);
    await expect(staff).toHaveURL(/\/first-login\/password/);
    await expect(staff.getByLabel("New password", { exact: true })).toHaveAttribute(
      "autocomplete",
      "new-password",
    );
    await staff.setViewportSize({ width: 320, height: 900 });
    await expect(
      staff.getByRole("button", { name: "Set password", exact: true }),
    ).toBeEnabled();
    expect((await new AxeBuilder({ page: staff }).analyze()).violations).toEqual([]);
    await staff.screenshot({
      path: "test-results/staff-first-password-320.png",
      fullPage: true,
    });
    const permanentPassword = "Prune rivière forêt 7 voyage unique";
    await staff.getByLabel("New password", { exact: true }).fill(permanentPassword);
    await staff
      .getByLabel("Confirm new password", { exact: true })
      .fill(permanentPassword);
    await staff.getByRole("button", { name: "Set password", exact: true }).click();
    await expect(staff).toHaveURL(/\/sign-in/);
    await staff
      .getByLabel("Email", { exact: true })
      .fill("teacher-directory@northstar-school.test");
    await staff.getByLabel("Password", { exact: true }).fill(permanentPassword);
    await staff.getByRole("button", { name: "Sign in", exact: true }).click();
    await expect(staff).toHaveURL(/\/classroom(?:\?|$)/);
    expect((await staff.request.get("/api/v1/staff-accounts")).status()).toBe(403);
    await expect(
      staff.getByRole("button", { name: "Oak daily register", exact: true }),
    ).toBeEnabled();
    const entranceRequests: string[] = [];
    const recordEntrance = (request: { url: () => string }) => {
      if (request.url().includes("/api/v1/"))
        entranceRequests.push(new URL(request.url()).pathname);
    };
    staff.on("request", recordEntrance);
    await staff.getByRole("link", { name: "Home", exact: true }).click();
    await expect(
      staff.getByRole("heading", { name: "Home", exact: true }),
    ).toBeVisible();
    await expect(
      staff.getByText("Signed in as Synthetic Teacher", { exact: true }),
    ).toBeVisible();
    await staff.getByRole("link", { name: "Apps", exact: true }).click();
    await expect(
      staff.getByRole("heading", { name: "Teaching & learning", exact: true }),
    ).toBeVisible();
    await expect(
      staff.getByRole("link", { name: "Accounts", exact: true }),
    ).toHaveCount(0);
    for (const width of [1440, 768, 320]) {
      await staff.setViewportSize({ width, height: 900 });
      expect(
        await staff.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
      ).toBe(true);
      expect((await new AxeBuilder({ page: staff }).analyze()).violations).toEqual([]);
      await staff.screenshot({
        path: `test-results/cw1-apps-${width}.png`,
        fullPage: true,
      });
    }
    expect(
      entranceRequests.filter(
        (path) =>
          path.startsWith("/api/v1/classroom") ||
          path.startsWith("/api/v1/staff-accounts"),
      ),
    ).toEqual([]);
    staff.off("request", recordEntrance);
    await staff.getByRole("link", { name: "Classroom", exact: true }).click();
    await staff
      .getByRole("button", { name: "Classroom tasks: My classes", exact: true })
      .click();
    await expect(
      staff.getByRole("button", { name: "My classes", exact: true }),
    ).toBeVisible();
    await staff.screenshot({
      path: "test-results/cw1-classes-320.png",
      fullPage: true,
    });
    await staff
      .getByRole("button", { name: "Oak daily register", exact: true })
      .click();
    await expect(staff.getByRole("group")).toHaveCount(4);
    await expect(
      staff.getByText("4 students · 4 still to mark", { exact: true }),
    ).toBeVisible();
    await expect(
      staff.getByText("Signed in as Synthetic Teacher", { exact: true }),
    ).toBeVisible();
    await expect(
      staff.getByRole("link", { name: "Accounts", exact: true }),
    ).toHaveCount(0);
    await staff
      .getByRole("group")
      .first()
      .getByRole("radio", { name: "Present", exact: true })
      .check();
    await staff.getByRole("link", { name: "Home", exact: true }).click();
    await expect(
      staff.getByRole("dialog", { name: "Discard unsaved marks?" }),
    ).toBeVisible();
    await expect(
      staff.getByRole("button", { name: "Stay", exact: true }),
    ).toBeFocused();
    await staff.screenshot({
      path: "test-results/cw1-draft-dialog-320.png",
      fullPage: true,
    });
    expect((await new AxeBuilder({ page: staff }).analyze()).violations).toEqual([]);
    await staff.keyboard.press("Tab");
    await expect(
      staff.getByRole("button", { name: "Discard", exact: true }),
    ).toBeFocused();
    await staff.keyboard.press("Tab");
    await expect(
      staff.getByRole("button", { name: "Stay", exact: true }),
    ).toBeFocused();
    await staff.keyboard.press("Escape");
    await expect(staff.getByRole("link", { name: "Home", exact: true })).toBeFocused();
    await expect(
      staff
        .getByRole("group")
        .first()
        .getByRole("radio", { name: "Present", exact: true }),
    ).toBeChecked();
    await staff.getByRole("button", { name: "Reload class", exact: true }).click();
    await staff.getByRole("button", { name: "Stay", exact: true }).click();
    await expect(
      staff
        .getByRole("group")
        .first()
        .getByRole("radio", { name: "Present", exact: true }),
    ).toBeChecked();
    const sessionBefore = (await (await staff.request.get("/api/v1/session")).json())
      .data;
    await staff.getByRole("link", { name: "My preferences", exact: true }).click();
    await staff.getByRole("button", { name: "Discard", exact: true }).click();
    await staff
      .getByRole("combobox", { name: "System language", exact: true })
      .selectOption("fr");
    await staff
      .getByRole("button", { name: "Enregistrer les préférences", exact: true })
      .click();
    await expect(staff.getByRole("status")).toHaveText(
      "Préférences enregistrées. Votre accès est inchangé.",
    );
    expect((await new AxeBuilder({ page: staff }).analyze()).violations).toEqual([]);
    await staff.screenshot({
      path: "test-results/staff-preferences-320.png",
      fullPage: true,
    });
    const sessionAfter = (await (await staff.request.get("/api/v1/session")).json())
      .data;
    expect(sessionAfter.actor_id).toEqual(sessionBefore.actor_id);
    expect((await staff.request.get("/api/v1/staff-accounts")).status()).toBe(403);
    await staff.goto("/accounts");
    await expect(
      staff.getByRole("button", { name: "Reload status", exact: true }),
    ).toBeEnabled();
    await staff.getByRole("button", { name: "Reload status", exact: true }).click();
    await expect(
      staff.getByText("Contact your account administrator if you need access."),
    ).toBeVisible();
    await expect(
      staff.getByRole("heading", { name: "Staff accounts", exact: true }),
    ).toHaveCount(0);
    expect((await new AxeBuilder({ page: staff }).analyze()).violations).toEqual([]);
    await staff.screenshot({
      path: "test-results/staff-blocked-accounts-320.png",
      fullPage: true,
    });
    await staff.goto("/classroom");
    await staff
      .getByRole("button", { name: "Oak daily register", exact: true })
      .click();

    await expect(staff.getByRole("group")).toHaveCount(4);
    for (const group of await staff.getByRole("group").all()) {
      await group.getByRole("radio", { name: "Present", exact: true }).check();
    }
    await staff.getByRole("button", { name: "Submit attendance", exact: true }).click();
    await expect(staff.getByRole("status")).toContainText("Attendance saved");
    await staff
      .getByRole("button", { name: "Correct attendance", exact: true })
      .click();
    await staff
      .getByRole("group")
      .first()
      .getByRole("radio", { name: "Late", exact: true })
      .check();
    await staff.route("**/api/v1/classroom/correct-attendance", async (route) => {
      const response = await route.fetch();
      expect(response.status()).toBe(200);
      await route.abort("connectionfailed");
    });
    await staff.getByRole("button", { name: "Save correction", exact: true }).click();
    await expect(staff.getByRole("status")).toContainText("Connection interrupted");
    await expect(
      staff.getByText("Correction result unconfirmed", { exact: true }),
    ).toBeVisible();
    await expect(staff.getByText("Saved register", { exact: true })).toHaveCount(0);
    await expect(
      staff.getByRole("button", { name: "Cancel correction", exact: true }),
    ).toBeDisabled();
    await staff.getByRole("link", { name: "Apps", exact: true }).click();
    await expect(staff).toHaveURL(/\/classroom(?:\?|$)/);
    await expect(staff.getByRole("status")).toContainText("reconcile");
    await expect(
      staff.getByRole("button", { name: "Sign out", exact: true }),
    ).toBeEnabled();
    await staff.screenshot({
      path: "test-results/cw1-uncertain-320.png",
      fullPage: true,
    });
    await staff.unroute("**/api/v1/classroom/correct-attendance");
    await staff.getByRole("button", { name: "Reload class", exact: true }).click();
    await expect(staff.getByRole("status")).toContainText(
      "requested marks are current",
    );
    for (const width of [1440, 320]) {
      await staff.setViewportSize({ width, height: 900 });
      expect(
        await staff.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
      ).toBe(true);
      expect((await new AxeBuilder({ page: staff }).analyze()).violations).toEqual([]);
      await staff.screenshot({
        path: `test-results/cw1-confirmed-${width}.png`,
        fullPage: true,
      });
    }

    await page.getByLabel("I confirm the institution and staff member above.").check();
    await page
      .getByRole("button", { name: "Suspend institution access", exact: true })
      .click();
    await expect(page.locator("#staff-directory-status")).toHaveText(
      "The account changed. Reload its current status before continuing.",
    );
    await page.getByRole("button", { name: "Reload status", exact: true }).click();
    await expect(page.locator("#staff-directory-status")).toHaveText(
      "Current account status loaded.",
    );
    await page.getByLabel("I confirm the institution and staff member above.").check();
    await page
      .getByRole("button", { name: "Suspend institution access", exact: true })
      .click();
    await expect(page.locator("#staff-directory-status")).toContainText(
      "Institution access suspended",
    );
    await staff.getByRole("button", { name: "Reload class", exact: true }).click();
    await expect(staff.getByRole("status")).toContainText(
      "Your access is no longer current",
    );
    await expect(staff.getByRole("group")).toHaveCount(0);
    expect((await staff.request.get("/api/v1/classroom/classes")).status()).toBe(401);
    expect((await staff.request.get("/api/v1/session")).status()).toBe(401);
    await signIn(staff, bootstrap.email, bootstrap.password);
    await expect(staff).toHaveURL(/\/accounts(?:\?|$)/);
    await protectedBack(staff);
    await protectedBack(staff);
    await expect(staff).toHaveURL(/\/classroom(?:\?|$)/);
    await expect(staff.getByRole("group")).toHaveCount(0);
    await expect(staff.getByRole("status")).toHaveText(
      "No classes are assigned to you today.",
    );
  } finally {
    await staffContext.close();
  }

  await page.getByRole("button", { name: "Sign out", exact: true }).click();
  await expect(page).toHaveURL(/\/sign-in/);
  expect((await page.request.get("/api/v1/session")).status()).toBe(401);
  await protectedBack(page);
  await expect(
    page.getByText("Contact your account administrator if you need access."),
  ).toBeVisible();
  await expect(page.getByLabel("Sign-in email", { exact: true })).toHaveCount(0);
});

test("staff entrances block anonymous identity and classroom session failure keeps sign-in recovery", async ({
  page,
}) => {
  for (const path of ["/staff/home", "/staff/apps"]) {
    await page.goto(path);
    await expect(
      page.getByRole("link", { name: "Sign in", exact: true }),
    ).toBeVisible();
    await expect(page.getByText("Signed in as", { exact: false })).toHaveCount(0);
    await expect(
      page.getByRole("link", { name: "Classroom", exact: true }),
    ).toHaveCount(0);
  }
  await page.route("**/api/v1/session", (route) => route.abort("connectionfailed"));
  await page.goto("/classroom");
  await expect(page.getByRole("status")).toContainText("Connection interrupted");
  await page.getByRole("link", { name: "Sign in", exact: true }).click();
  await expect(page).toHaveURL(/\/sign-in/);
});
