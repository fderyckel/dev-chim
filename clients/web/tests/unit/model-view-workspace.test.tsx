import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { run as runAccessibilityScan } from "axe-core";
import { describe, expect, it } from "vitest";

import {
  validateModelViewSet,
  type ModelViewRecord,
  type ModelViewSetDefinition,
} from "../../src/model-views/model-view-contract";
import { ModelViewWorkspace } from "../../src/model-views/model-view-workspace";

const periodViews = {
  schemaVersion: 1,
  sourceRef: "academics.calendar.entries",
  title: "Academic calendar entries",
  identityField: "id",
  fields: [
    { ref: "id", label: "Identity", type: "text" },
    { ref: "title", label: "Name", type: "text" },
    { ref: "kind", label: "Type", type: "status" },
    { ref: "start_on", label: "Starts", type: "date" },
    { ref: "end_on", label: "Ends", type: "date" },
  ],
  views: [
    {
      kind: "calendar",
      titleField: "title",
      startField: "start_on",
      endField: "end_on",
      statusField: "kind",
    },
    { kind: "list", fields: ["title", "kind", "start_on", "end_on"] },
    { kind: "form", fields: ["title", "kind", "start_on", "end_on"] },
    {
      kind: "gantt",
      titleField: "title",
      startField: "start_on",
      endField: "end_on",
      groupField: "kind",
    },
  ],
  defaultView: "calendar",
} as const satisfies ModelViewSetDefinition;

const periods: ReadonlyArray<ModelViewRecord> = [
  {
    id: "term-1",
    title: "Term 1",
    kind: "Academic period",
    start_on: "2026-09-01",
    end_on: "2026-12-18",
  },
  {
    id: "closure-1",
    title: "Founders' Day",
    kind: "Closure",
    start_on: "2026-10-15",
    end_on: "2026-10-15",
  },
];

const classViews = {
  schemaVersion: 1,
  sourceRef: "classroom.assigned_classes",
  title: "Assigned classes",
  identityField: "id",
  fields: [
    { ref: "id", label: "Identity", type: "text" },
    { ref: "label", label: "Class", type: "text" },
    { ref: "code", label: "Code", type: "text" },
  ],
  views: [
    { kind: "list", fields: ["label", "code"] },
    { kind: "form", fields: ["label", "code"] },
  ],
  defaultView: "list",
} as const satisfies ModelViewSetDefinition;

describe("the governed model-view workspace", () => {
  it("renders only declared views and switches one calendar dataset between them", async () => {
    const user = userEvent.setup();
    const { rerender } = render(
      <ModelViewWorkspace
        definition={periodViews}
        records={periods}
        selectedDate="2026-10-15"
      />,
    );

    const calendarTab = screen.getByRole("tab", { name: "Calendar" });
    expect(calendarTab).toHaveAttribute("aria-selected", "true");
    expect(
      screen.getByRole("button", { name: /15 Oct 2026, Term 1, Founders' Day/ }),
    ).toBeVisible();

    rerender(
      <ModelViewWorkspace
        definition={periodViews}
        records={periods}
        selectedDate="2026-12-01"
      />,
    );
    expect(await screen.findByRole("heading", { name: "December 2026" })).toBeVisible();

    calendarTab.focus();
    await user.keyboard("{ArrowRight}");
    expect(screen.getByRole("tab", { name: "List" })).toHaveFocus();
    expect(screen.getByRole("tab", { name: "List" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(
      screen.getByRole("table", { name: "Academic calendar entries" }),
    ).toBeVisible();
    expect(screen.getByRole("cell", { name: "Founders' Day" })).toBeVisible();

    await user.click(screen.getByRole("tab", { name: "Gantt" }));
    expect(
      screen.getByRole("img", {
        name: /^Academic calendar entries timeline/,
      }),
    ).toBeVisible();
    expect(screen.getByRole("list", { name: "Exact Gantt dates" })).toHaveTextContent(
      "1 Sept 2026 – 18 Dec 2026",
    );

    const accessibility = await runAccessibilityScan(document.body, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(accessibility.violations).toEqual([]);
  });

  it("does not infer Calendar or Gantt for a model that declares only List and Form", async () => {
    const user = userEvent.setup();
    render(
      <ModelViewWorkspace
        definition={classViews}
        records={[{ id: "class-1", label: "Year 6 Blue", code: "Y6-B" }]}
      />,
    );

    expect(screen.getByRole("tab", { name: "List" })).toBeVisible();
    expect(screen.getByRole("tab", { name: "Form" })).toBeVisible();
    expect(screen.queryByRole("tab", { name: "Calendar" })).not.toBeInTheDocument();
    expect(screen.queryByRole("tab", { name: "Gantt" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("tab", { name: "Form" }));
    expect(
      screen.getByRole("group", { name: "Assigned classes record" }),
    ).toHaveTextContent("Year 6 Blue");
  });

  it("fails closed when a dated view references a non-date field", () => {
    const invalid = {
      ...periodViews,
      fields: periodViews.fields.map((field) =>
        field.ref === "start_on" ? { ...field, type: "text" as const } : field,
      ),
    };

    expect(validateModelViewSet(invalid)).toContain(
      "calendar view requires a date-valued start field.",
    );
    expect(validateModelViewSet(invalid)).toContain(
      "gantt view requires a date-valued start field.",
    );
  });
});
