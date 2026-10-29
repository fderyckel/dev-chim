import { describe, expect, it } from "vitest";
import {
  defaultAppSections,
  defaultHomeLayout,
  moveLayoutItem,
  reorder,
  validLayoutLabel,
  validLayoutSections,
} from "../../src/lib/demo-layout";
import { demoNavigation, findDemoDestinations } from "../../src/lib/demo-navigation";

describe("bounded demo presentation layouts", () => {
  it("accepts aliases across sections but rejects authority, URLs, unknown destinations and ambiguous names", () => {
    const groups = defaultAppSections();
    groups[0].items.push("calendar");
    expect(validLayoutSections(groups)).toBe(true);
    expect(validLayoutSections([])).toBe(true);
    for (const sections of [
      [{ ...groups[0], href: "/accounts" }],
      [{ ...groups[0], capability: "all" }],
      [{ ...groups[0], items: ["safeguarding"] }],
      [{ ...groups[0], items: ["calendar", "calendar"] }],
      [{ ...groups[0], label: " " }],
      [{ ...groups[0], label: "<script>" }],
      [{ ...groups[0], id: "../school" }],
      [{ ...groups[0] }, { ...groups[1], label: groups[0].label.toUpperCase() }],
    ])
      expect(validLayoutSections(sections)).toBe(false);
    expect(validLayoutLabel("a".repeat(61))).toBe(false);
    expect(validLayoutLabel("Line\nbreak")).toBe(false);
  });

  it("moves and reorders links without mutating source data or creating duplicate target placements", () => {
    const before = defaultAppSections();
    const moved = moveLayoutItem(before, before[1].id, "calendar", before[0].id);
    expect(moved[0].items).toEqual(["students", "calendar"]);
    expect(moved[1].items).toEqual(["educators"]);
    expect(before[1].items).toEqual(["educators", "calendar"]);
    expect(moveLayoutItem(moved, moved[1].id, "calendar", moved[0].id)).toEqual(moved);
    expect(reorder(moved[0].items, 1, -1)).toEqual(["calendar", "students"]);
    expect(reorder(moved, 0, -1)).toEqual(moved);
    expect(defaultHomeLayout().sections[0].items).toEqual([
      "students",
      "contacts",
      "educators",
      "calendar",
    ]);
  });

  it("deduplicates search even with repeated aliases and finds a custom group name", () => {
    const groups = defaultAppSections();
    groups[0] = { ...groups[0], label: "Planning", items: ["calendar"] };
    for (const college of [false, true]) {
      const { apps } = demoNavigation(college);
      expect(findDemoDestinations(apps, "calendar", groups)).toHaveLength(1);
      expect(findDemoDestinations(apps, "Planning", groups)[0].destination.id).toBe(
        "calendar",
      );
    }
  });
});
