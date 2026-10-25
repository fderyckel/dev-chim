import { describe, expect, it } from "vitest";
import {
  demoNavigation,
  findDemoDestinations,
  isDemoRouteSection,
} from "../../src/lib/demo-navigation";

describe("local demo navigation", () => {
  it("exposes only current pages and never turns an unknown or planned app into a route", () => {
    const { apps, destinations } = demoNavigation(false);
    expect(new Set(destinations.map((page) => page.id)).size).toBe(6);
    expect(apps.flatMap((app) => app.destinations).map((page) => page.href)).toEqual([
      "/demo/students",
      "/demo/contacts",
      "/demo/educators",
      "/demo/calendar",
    ]);
    for (const value of [
      "admissions",
      "safeguarding",
      "../students",
      "overview",
      "",
      "constructor",
    ]) {
      expect(isDemoRouteSection(value)).toBe(false);
    }
    expect(isDemoRouteSection("apps")).toBe(true);
  });

  it("finds family and teaching vocabulary without searching or inferring people", () => {
    for (const college of [false, true]) {
      const { apps } = demoNavigation(college);
      expect(
        findDemoDestinations(apps, "family contacts").map(
          (match) => match.destination.id,
        ),
      ).toEqual(["contacts"]);
      expect(findDemoDestinations(apps, "  lecturers  ")[0].destination.label).toBe(
        college ? "Instructors" : "Educators",
      );
      expect(findDemoDestinations(apps, "student S001")).toEqual([]);
      expect(findDemoDestinations(apps, "send message")).toEqual([]);
    }
  });
});
