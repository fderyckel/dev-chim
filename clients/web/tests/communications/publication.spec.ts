import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
async function persona(page: Page, name: string) {
  await page.getByText("Fictional proof personas", { exact: true }).click();
  await page
    .getByRole("button", { name: "Use fictional " + name, exact: true })
    .click();
  await page.waitForLoadState("networkidle");
}
async function snapshot(page: Page, name: string, width = 1280) {
  await page.setViewportSize({ width, height: 900 });
  expect((await new AxeBuilder({ page }).analyze()).violations).toEqual([]);
  const overflow = await page.evaluate(() =>
    Array.from(document.querySelectorAll("main,main *"))
      .filter((el) => el.getBoundingClientRect().right > window.innerWidth + 1)
      .map((el) => ({
        tag: el.tagName,
        className: el.className,
        width: el.getBoundingClientRect().width,
      })),
  );
  expect(overflow).toEqual([]);
  await page.screenshot({
    path: "test-results/comm1-" + name + "-" + width + ".png",
    fullPage: true,
  });
}
test("independent local publication, fresh corrected receipt, withdrawal, receipt-off and stale review", async ({
  page,
  browser,
}) => {
  await page.goto("/communications");
  expect(
    (
      await page.request.get(
        "/api/v1/communications/status?notice_id=00000000-0000-4000-8000-000000000001",
      )
    ).status(),
  ).toBe(401);
  await persona(page, "author");
  await expect(
    page.getByRole("button", { name: "Save draft", exact: true }),
  ).toBeEnabled();
  await expect(page.getByLabel("Request receipt confirmation")).not.toBeChecked();
  await page.getByRole("button", { name: "Save draft", exact: true }).click();
  await expect(page.getByText("Check the highlighted fields.")).toBeFocused();
  await expect(page.getByLabel("Title", { exact: true })).toHaveAttribute(
    "aria-invalid",
    "true",
  );
  await page.getByLabel("Title", { exact: true }).fill("Staff collection time");
  await page
    .getByRole("textbox", { name: "Body", exact: true })
    .fill("Collection is at 15:00. <script>never run</script>");
  await page.getByLabel("Request receipt confirmation").check();
  await snapshot(page, "write", 320);
  await page.getByRole("button", { name: "Save draft", exact: true }).click();
  await expect(page.getByText("Draft saved. Review the audience next.")).toBeVisible();
  const noticePath = await page
    .getByRole("link", { name: "Recipient", exact: true })
    .getAttribute("href");
  if (!noticePath) throw new Error("Notice link absent");
  await page.getByRole("button", { name: "Review audience", exact: true }).focus();
  await page.keyboard.press("Enter");
  await expect(
    page.getByRole("button", { name: "Submit for approval", exact: true }),
  ).toBeVisible();
  await snapshot(page, "review");
  await page.getByRole("button", { name: "Submit for approval", exact: true }).click();
  await expect(
    page.getByText("Submitted for a different authorized person to approve."),
  ).toBeVisible();
  await page.goto(noticePath + "/review");
  await expect(
    page.getByText(
      "Access to this action could not be confirmed. Use an authorized account.",
    ),
  ).toBeVisible();
  await snapshot(page, "self-approval-denied", 320);

  const approverContext = await browser.newContext({
    baseURL: "https://localhost:3025",
    ignoreHTTPSErrors: true,
  });
  const approver = await approverContext.newPage();
  await approver.goto(noticePath + "/review");
  await persona(approver, "approver");
  await expect(
    approver.getByRole("button", { name: "Approve and publish", exact: true }),
  ).toBeEnabled();
  await snapshot(approver, "approval", 320);
  await approver.route(
    "**/api/v1/communications/approve-operation",
    async (route) => {
      const response = await route.fetch();
      expect(response.status()).toBe(200);
      await route.abort("failed");
    },
    { times: 1 },
  );
  await approver
    .getByRole("button", { name: "Approve and publish", exact: true })
    .click();
  await expect(
    approver.getByRole("button", { name: "Check this request", exact: true }),
  ).toBeVisible();
  await approver.reload();
  await approver
    .getByRole("button", { name: "Check this request", exact: true })
    .click();
  await expect(
    approver.getByText(
      "The original request was recorded. The current task has been reloaded.",
      { exact: true },
    ),
  ).toBeVisible();
  await approver.getByRole("link", { name: "View results", exact: true }).click();
  await expect(approver.getByText("Opened 0 of 2", { exact: true })).toBeVisible();

  const recipientContext = await browser.newContext({
    hasTouch: true,
    baseURL: "https://localhost:3025",
    ignoreHTTPSErrors: true,
  });
  const recipient = await recipientContext.newPage();
  await recipient.goto(noticePath);
  await persona(recipient, "recipient");
  await expect(
    recipient.getByText("Openings and receipt confirmations are recorded.", {
      exact: true,
    }),
  ).toBeVisible();
  await expect(
    recipient.getByText("Collection is at 15:00.", { exact: false }),
  ).not.toBeVisible();
  await expect(
    recipient.getByRole("button", { name: "Confirm receipt", exact: true }),
  ).not.toBeVisible();
  await expect(
    recipient.getByText("I acknowledge receipt of this notice.", { exact: true }),
  ).not.toBeVisible();
  await snapshot(recipient, "before-opening", 320);
  await recipient.getByRole("button", { name: "Open notice", exact: true }).focus();
  await recipient.keyboard.press("Enter");
  await expect(
    recipient.getByText("Collection is at 15:00. <script>never run</script>", {
      exact: true,
    }),
  ).toBeVisible();
  expect(await recipient.locator("article script").count()).toBe(0);
  await expect(
    recipient.getByText("I acknowledge receipt of this notice.", {
      exact: true,
    }),
  ).toBeVisible();
  await recipient.evaluate(() => {
    document.documentElement.style.fontSize = "200%";
  });
  await snapshot(recipient, "text-scaled", 320);
  await recipient.evaluate(() => {
    document.documentElement.style.fontSize = "";
  });
  await recipient.getByRole("button", { name: "Confirm receipt", exact: true }).tap();
  await expect(
    recipient.getByText("Receipt confirmed for this version.", { exact: true }),
  ).toBeVisible();
  await snapshot(recipient, "confirmed");
  await page.goto(noticePath + "/write");
  await page
    .getByRole("textbox", { name: "Body", exact: true })
    .fill("Collection is at 12:00.");
  await page
    .getByLabel("Correction reason", { exact: true })
    .fill("Collection time correction");
  await expect(page.getByRole("textbox", { name: "Body", exact: true })).toHaveValue(
    "Collection is at 12:00.",
  );
  const correctionRequest = page.waitForRequest((r) =>
    r.url().endsWith("/prepare-operation"),
  );
  await page.getByRole("button", { name: "Review audience", exact: true }).click();
  expect((await correctionRequest).postDataJSON().body).toBe("Collection is at 12:00.");
  await expect(
    page.getByRole("button", { name: "Submit for approval", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Submit for approval", exact: true }).click();
  await approver.goto(noticePath + "/review");
  await expect(
    approver.getByText("Collection is at 12:00.", { exact: true }),
  ).toBeVisible();
  await approver
    .getByRole("button", {
      name: "Approve and publish correction",
      exact: true,
    })
    .click();
  await expect(approver.getByText("Notice published.", { exact: true })).toBeVisible();
  await recipient.reload();
  await expect(
    recipient.getByRole("button", { name: "Confirm receipt", exact: true }),
  ).not.toBeVisible();
  await expect(
    recipient.getByRole("button", { name: "Open notice", exact: true }),
  ).toBeVisible();
  await recipient.getByRole("button", { name: "Open notice", exact: true }).click();
  await expect(
    recipient.getByText("Collection is at 12:00.", { exact: true }),
  ).toBeVisible();
  await snapshot(recipient, "correction", 320);

  await recipient.route(
    "**/api/v1/communications/confirm-receipt",
    async (route) => {
      const response = await route.fetch();
      expect(response.status()).toBe(200);
      await route.abort("failed");
    },
    { times: 1 },
  );
  await recipient.getByRole("button", { name: "Confirm receipt", exact: true }).click();
  await expect(
    recipient.getByText(
      "The result is uncertain. Keep this request until it has been checked.",
      { exact: true },
    ),
  ).toBeVisible();
  await snapshot(recipient, "uncertain", 320);
  await recipient.reload();
  await expect(
    recipient.getByRole("button", { name: "New notice", exact: true }),
  ).toBeDisabled();
  await recipient
    .getByRole("button", { name: "Check this request", exact: true })
    .click();
  await expect(
    recipient.getByText(
      "The original request was recorded. The current task has been reloaded.",
      { exact: true },
    ),
  ).toBeVisible();
  await page.goto(noticePath + "/write");
  await page.getByRole("button", { name: "Request withdrawal", exact: true }).click();
  await page
    .getByLabel("Withdrawal reason", { exact: true })
    .fill("Superseded staff arrangements");
  await page.getByRole("button", { name: "Review withdrawal", exact: true }).click();
  await page.getByRole("button", { name: "Submit for approval", exact: true }).click();
  await approver.goto(noticePath + "/review");
  await snapshot(approver, "withdrawal-review", 320);
  await approver
    .getByRole("button", { name: "Approve withdrawal", exact: true })
    .click();
  await recipient.reload();
  await expect(
    recipient.getByRole("heading", { name: "Notice withdrawn", exact: true }),
  ).toBeVisible();
  await expect(
    recipient.getByRole("button", { name: "Confirm receipt", exact: true }),
  ).not.toBeVisible();
  await expect(
    recipient.getByText("Collection is at 12:00.", { exact: true }),
  ).not.toBeVisible();
  await snapshot(recipient, "withdrawn", 320);

  await page.getByRole("link", { name: "New notice", exact: true }).click();
  await expect(page.getByRole("textbox", { name: "Title", exact: true })).toHaveValue(
    "",
  );
  await expect(page.getByRole("textbox", { name: "Body", exact: true })).toHaveValue(
    "",
  );
  await expect(page.getByLabel("Request receipt confirmation")).not.toBeChecked();
  await page.getByLabel("Title", { exact: true }).fill("Ordinary staff update");
  await page
    .getByRole("textbox", { name: "Body", exact: true })
    .fill("Staff meeting arrangements.");
  await page.getByRole("button", { name: "Save draft", exact: true }).click();
  const offPath = await page
    .getByRole("link", { name: "Recipient", exact: true })
    .getAttribute("href");
  await page.getByRole("button", { name: "Review audience", exact: true }).click();
  await page.getByRole("button", { name: "Submit for approval", exact: true }).click();
  await approver.goto(offPath + "/review");
  await approver
    .getByRole("button", { name: "Approve and publish", exact: true })
    .click();
  await recipient.goto(offPath!);
  await expect(
    recipient.getByText("No receipt confirmation requested.", { exact: true }),
  ).toBeVisible();
  await snapshot(recipient, "receipt-off", 320);

  await page.goto("/communications");
  await page.getByLabel("Title", { exact: true }).fill("Stale source trial");
  await page
    .getByRole("textbox", { name: "Body", exact: true })
    .fill("Changed audience must stop approval.");
  await page.getByRole("button", { name: "Save draft", exact: true }).click();
  const stalePath = await page
    .getByRole("link", { name: "Recipient", exact: true })
    .getAttribute("href");
  await page.getByRole("button", { name: "Review audience", exact: true }).click();
  await page.getByRole("button", { name: "Submit for approval", exact: true }).click();
  expect(
    (
      await page.request.post("/proof/change-source", {
        headers: { origin: "https://localhost:3025" },
      })
    ).status(),
  ).toBe(204);
  await approver.goto(stalePath + "/review");
  await approver
    .getByRole("button", { name: "Approve and publish", exact: true })
    .click();
  await expect(
    approver.getByText(
      "This preparation changed or expired. Refresh it and submit it for a new approval.",
      { exact: true },
    ),
  ).toBeVisible();
  await snapshot(approver, "stale", 320);
  for (let i = 0; i < 3; i++) {
    await page.goto("/communications");
    await page.getByLabel("Title", { exact: true }).fill("Capacity trial " + i);
    await page
      .getByRole("textbox", { name: "Body", exact: true })
      .fill("Local proof capacity.");
    await page.getByRole("button", { name: "Save draft", exact: true }).click();
  }
  await expect(
    page.getByText(
      "This local proof allows five notices, two versions per notice and 25 staff. The limit has been reached.",
      { exact: true },
    ),
  ).toBeVisible();
  await snapshot(page, "capacity", 320);
  await approverContext.close();
  await recipientContext.close();
});
