import { fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { ModelViewWorkspace } from "../../src/model-views/model-view-workspace";
import type {
  CalendarViewContext,
  ModelViewRecord,
  ModelViewSetDefinition,
} from "../../src/model-views/model-view-contract";
import { calendarEntries } from "../../src/model-views/calendar-data";
import { monthDays, parseLocalDate } from "../../src/model-views/local-date";
import { DemoCalendar } from "../../src/components/demo-calendar";
import { projectDemo, type DemoPack } from "../../src/lib/demo-instance";
import collegePack from "../../../../demo-data/packs/us-community-college.json";

// A non-school source proves that the view has no dependency on demo field names or semantics.
const definition = {
  schemaVersion: 1,
  sourceRef: "projects.milestones",
  title: "Project milestones",
  identityField: "key",
  fields: [
    { ref: "key", label: "Key", type: "text" },
    { ref: "summary", label: "Summary", type: "text" },
    { ref: "from", label: "From", type: "date" },
    { ref: "through", label: "Through", type: "date" },
    { ref: "category", label: "Category", type: "status" },
    { ref: "team", label: "Team", type: "text" },
  ],
  views: [
    {
      kind: "calendar",
      titleField: "summary",
      startField: "from",
      endField: "through",
      statusField: "category",
      scopeField: "team",
      contextStatuses: ["Phase"],
    },
    { kind: "list", fields: ["summary", "from", "through", "team"] },
  ],
  defaultView: "calendar",
} as const satisfies ModelViewSetDefinition;
const context: CalendarViewContext = {
  sourceKey: "project.one",
  referenceDate: "2024-02-29",
  referenceLabel: "Review date",
  coverageStart: "2024-01-01",
  coverageEnd: "2025-01-31",
  scopeLabel: "Project one",
  timeZone: "Pacific/Auckland",
  locale: "en-GB",
  weekStartsOn: 0,
};
const records: ModelViewRecord[] = [
  {
    key: "phase",
    summary: "Build phase",
    from: "2024-01-15",
    through: "2024-04-02",
    category: "Phase",
    team: "Platform",
  },
  ...["alpha", "beta", "gamma", "delta"].map((key) => ({
    key,
    summary: "Review",
    from: "2024-02-29",
    through: "2024-03-01",
    category: "Milestone",
    team: key,
  })),
];

describe("reusable Month and Agenda", () => {
  it("selects the first supplied date when navigating into partial-month coverage", async () => {
    const user = userEvent.setup();
    render(
      <ModelViewWorkspace
        definition={definition}
        records={records}
        calendarContext={{ ...context, coverageStart: "2024-01-15" }}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Previous month" }));
    expect(screen.getByLabelText("Jump to date")).toHaveValue("2024-01-15");
    expect(screen.getByRole("button", { name: "Previous month" })).toBeDisabled();
    expect(screen.getByRole("region", { name: "Selected day" })).toHaveTextContent(
      "Build phase",
    );
  });
  it("keeps declared instructional weekdays separate from the displayed week start", () => {
    const data = projectDemo(collegePack as unknown as DemoPack);
    render(<DemoCalendar data={{ ...data, instructionalWeekdays: [2, 6] }} />);
    expect(
      screen.getByText(/Configured instructional weekdays: Tue, Sat/),
    ).toBeVisible();
    expect(
      document.querySelector(".c-date-weekdays")?.firstElementChild,
    ).toHaveTextContent("Sun");
    expect(screen.getByRole("region", { name: "Selected day" })).not.toHaveTextContent(
      "No instruction",
    );
  });
  it("keeps month, mode, filter and record selection across List and Calendar, with complete overflow and details", async () => {
    const user = userEvent.setup();
    render(
      <ModelViewWorkspace
        definition={definition}
        records={records}
        calendarContext={context}
      />,
    );
    expect(screen.getByRole("heading", { name: "February 2024" })).toBeVisible();
    await user.click(
      screen.getByRole("button", { name: "2 more entries on 29 Feb 2024" }),
    );
    const day = screen.getByRole("region", { name: "Selected day" });
    expect(
      within(day).getAllByRole("button", { name: /Milestone Review/ }),
    ).toHaveLength(4);
    const entry = within(day).getByRole("button", { name: /Milestone Review.*alpha/ });
    await user.click(entry);
    expect(screen.getByRole("region", { name: "Entry details" })).toHaveTextContent(
      "29 Feb 2024 – 1 Mar 2024",
    );
    await user.click(screen.getByRole("button", { name: "Close details" }));
    expect(entry).toHaveFocus();
    await user.click(entry);
    await user.click(screen.getByRole("tab", { name: "List" }));
    await user.click(screen.getByRole("tab", { name: "Calendar" }));
    expect(screen.getByRole("region", { name: "Entry details" })).toHaveTextContent(
      "alpha",
    );
    await user.click(screen.getByRole("button", { name: "Close details" }));
    expect(
      within(screen.getByRole("region", { name: "Selected day" })).getByRole("heading"),
    ).toHaveFocus();
    await user.selectOptions(screen.getByLabelText("Show"), "Milestone");
    await user.click(screen.getByRole("button", { name: "Agenda" }));
    await user.click(screen.getByRole("tab", { name: "List" }));
    expect(screen.getAllByRole("row")).toHaveLength(5);
    await user.click(screen.getByRole("tab", { name: "Calendar" }));
    expect(screen.getByRole("button", { name: "Agenda" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    expect(screen.getByLabelText("Show")).toHaveValue("Milestone");
    await user.click(screen.getByRole("button", { name: "Next month" }));
    expect(screen.getByRole("heading", { name: "March 2024" })).toBeVisible();
    expect(screen.getByRole("region", { name: "March 2024 agenda" })).toHaveTextContent(
      "1 Mar 2024",
    );
    await user.click(screen.getByRole("button", { name: "Review date" }));
    expect(screen.getByRole("heading", { name: "February 2024" })).toBeVisible();
    expect(document.querySelector("button button")).toBeNull();
  });

  it("retains ongoing range context, allows an empty loaded month and resets when the source changes", async () => {
    const user = userEvent.setup();
    const { rerender } = render(
      <ModelViewWorkspace
        definition={definition}
        records={records}
        calendarContext={context}
      />,
    );
    expect(
      screen.getByRole("region", { name: "Ongoing date ranges" }),
    ).toHaveTextContent("Continues from 15 Jan 2024");
    fireEvent.change(screen.getByLabelText("Jump to date"), {
      target: { value: "2024-12-31" },
    });
    expect(screen.getByRole("heading", { name: "December 2024" })).toBeVisible();
    expect(screen.getByRole("status")).toHaveTextContent(
      "No entries in the supplied month",
    );
    expect(screen.getByRole("button", { name: "Next month" })).toBeEnabled();
    await user.click(screen.getByRole("tab", { name: "List" }));
    await user.selectOptions(screen.getByLabelText("Show"), "Milestone");
    expect(screen.getByRole("status")).toHaveTextContent(
      "No matching entries in this month",
    );
    await user.click(screen.getByRole("button", { name: "Clear filters" }));
    expect(screen.getByLabelText("Show")).toHaveValue("");
    expect(screen.getByRole("status")).toHaveTextContent(
      "No entries in the supplied month",
    );
    rerender(
      <ModelViewWorkspace
        definition={definition}
        records={records}
        calendarContext={{ ...context, sourceKey: "project.two" }}
      />,
    );
    expect(screen.getByRole("heading", { name: "February 2024" })).toBeVisible();
  });

  it.each([
    { invalid: [{ ...records[0], from: "2024-02-30" }] },
    { invalid: [{ ...records[0], from: "2024-04-03", through: "2024-04-02" }] },
    { invalid: [{ ...records[0], key: null }] },
    { invalid: [records[0], records[0]] },
  ])(
    "does not render invalid or duplicate data as an empty complete calendar",
    ({ invalid }) => {
      render(
        <ModelViewWorkspace
          definition={definition}
          records={invalid}
          calendarContext={context}
        />,
      );
      expect(screen.getByRole("alert")).toHaveTextContent("Calendar data unavailable");
      expect(
        screen.queryByRole("region", { name: "Calendar entries" }),
      ).not.toBeInTheDocument();
    },
  );

  it("rejects bad display context and unknown view kinds without crashing", () => {
    const { rerender } = render(
      <ModelViewWorkspace
        definition={definition}
        records={records}
        calendarContext={{ ...context, locale: "bad_", timeZone: "not/a/zone" }}
      />,
    );
    expect(screen.getByRole("alert")).toHaveTextContent("locale or time zone");
    rerender(
      <ModelViewWorkspace
        definition={
          {
            ...definition,
            views: [{ kind: "unknown" }],
          } as unknown as ModelViewSetDefinition
        }
        records={records}
      />,
    );
    expect(screen.getByRole("alert")).toHaveTextContent("view kind is unsupported");
  });

  it("preserves all records in a declared 600-entry leap-day overlap fixture without expanding a two-year range", () => {
    const stress = Array.from({ length: 600 }, (_, index) => ({
      key: `record-${index}`,
      summary: `Review ${index}`,
      from: "2024-02-29",
      through: "2024-02-29",
      category: "Milestone",
      team: "Platform",
    }));
    const parsed = calendarEntries(
      definition,
      [...stress, { ...records[0], from: "2023-01-01", through: "2025-01-01" }],
      definition.views[0],
    );
    expect(parsed.issues).toEqual([]);
    expect(parsed.entries).toHaveLength(601);
    const started = performance.now();
    render(
      <ModelViewWorkspace
        definition={definition}
        records={stress}
        calendarContext={context}
      />,
    );
    expect(
      within(screen.getByRole("region", { name: "Selected day" })).getAllByRole(
        "button",
      ),
    ).toHaveLength(600);
    expect(document.querySelectorAll(".c-date-cell").length).toBeLessThanOrEqual(42);
    expect(performance.now() - started).toBeLessThan(4000);
    expect(monthDays("2024-02", 0).filter((day) => day !== null)).toHaveLength(29);
    expect(monthDays("2024-02", 0).indexOf(parseLocalDate("2024-02-01"))).toBe(4);
    expect(monthDays("2024-02", 1).indexOf(parseLocalDate("2024-02-01"))).toBe(3);
  });
});
