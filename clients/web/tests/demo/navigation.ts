import type { Page } from "@playwright/test";

export async function openDemoDestination(page: Page, label: string) {
  await page
    .getByRole("navigation", { name: "Primary navigation" })
    .getByRole("link", { name: "Apps", exact: true })
    .click();
  if (label === "Contacts" || label === "Families & guardians") {
    await page
      .getByRole("main")
      .getByRole("link", { name: "Students", exact: true })
      .click();
    await page
      .getByRole("navigation", { name: "Workspace navigation" })
      .getByRole("link", { name: label, exact: true })
      .click();
  } else {
    await page
      .getByRole("main")
      .getByRole("link", { name: label, exact: true })
      .click();
  }
}
