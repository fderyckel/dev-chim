export const demoRouteSections = [
  "apps",
  "students",
  "contacts",
  "educators",
  "calendar",
] as const;

export type DemoSection = "overview" | (typeof demoRouteSections)[number];
export type DemoDestination = Readonly<{
  id: DemoSection;
  label: string;
  href: string;
  keywords: string;
}>;
export type DemoApp = Readonly<{
  id: "students" | "educators" | "calendar";
  label: string;
  description: string;
  destinations: readonly DemoDestination[];
}>;

export function isDemoRouteSection(
  value: string,
): value is Exclude<DemoSection, "overview"> {
  return demoRouteSections.some((section) => section === value);
}

export function demoNavigation(college: boolean) {
  const home: DemoDestination = {
    id: "overview",
    label: "Home",
    href: "/",
    keywords: "overview institution summary",
  };
  const appsPage: DemoDestination = {
    id: "apps",
    label: "Apps",
    href: "/demo/apps",
    keywords: "applications workspaces",
  };
  const apps: readonly DemoApp[] = [
    {
      id: "students",
      label: "Students",
      description: college ? "Students and contacts" : "Students and family contacts",
      destinations: [
        {
          id: "students",
          label: "Students",
          href: "/demo/students",
          keywords: "learners enrolment enrollment register programme course sections",
        },
        {
          id: "contacts",
          label: college ? "Contacts" : "Families & guardians",
          href: "/demo/contacts",
          keywords: "family families parents guardians contacts relationships",
        },
      ],
    },
    {
      id: "educators",
      label: college ? "Instructors" : "Educators",
      description: college
        ? "Instructors and support staff"
        : "Educators and support staff",
      destinations: [
        {
          id: "educators",
          label: college ? "Instructors" : "Educators",
          href: "/demo/educators",
          keywords:
            "people teachers lecturers instructors educators staff responsibilities",
        },
      ],
    },
    {
      id: "calendar",
      label: "Calendar",
      description: "Academic periods, closures and events",
      destinations: [
        {
          id: "calendar",
          label: "Calendar",
          href: "/demo/calendar",
          keywords: "academic calendar dates terms semesters closures events agenda",
        },
      ],
    },
  ];
  return {
    home,
    appsPage,
    apps,
    destinations: [home, appsPage, ...apps.flatMap((app) => app.destinations)],
  };
}

export function findDemoDestinations(
  apps: readonly DemoApp[],
  query: string,
  groups: readonly { label: string; items: readonly string[] }[] = [],
) {
  const words = query.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
  return apps.flatMap((app) =>
    app.destinations
      .filter((destination) => {
        const text = `${destination.label} ${destination.keywords} ${app.label} ${groups
          .filter((group) => group.items.includes(destination.id))
          .map((group) => group.label)
          .join(" ")}`.toLocaleLowerCase();
        return words.every((word) => text.includes(word));
      })
      .map((destination) => ({ app, destination })),
  );
}
