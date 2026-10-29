import type { components } from "../generated/public/staff-schema";

type Presentation = components["schemas"]["StaffPreferencesResponse"]["data"];
type DestinationId = "classroom" | "accounts" | "preferences";
export type StaffWorkspaceSection = Readonly<{
  id: string;
  label: string;
  entries: readonly DestinationId[];
}>;

// Labels and placement are presentation configuration, never route or action identity.
export const staffWorkspaceDefaults = {
  home: [{ id: "daily-work", label: "My work", entries: ["classroom"] }],
  apps: [
    { id: "learning", label: "Teaching & learning", entries: ["classroom"] },
    { id: "administration", label: "Administration", entries: ["accounts"] },
    { id: "personal", label: "Personal", entries: ["preferences"] },
  ],
} as const satisfies Record<"home" | "apps", readonly StaffWorkspaceSection[]>;

const destinations = {
  classroom: {
    id: "classroom",
    label: "Classroom",
    href: "/classroom",
    description: "My classes and attendance",
  },
  accounts: {
    id: "accounts",
    label: "Accounts",
    href: "/accounts",
    description: "Staff accounts",
  },
  preferences: {
    id: "preferences",
    label: "My preferences",
    href: "/my-preferences",
    description: "Language and personal settings",
  },
} as const;

export function staffWorkspaceSections(
  presentation: Presentation,
  arrangement: readonly StaffWorkspaceSection[],
) {
  const seen = new Set<string>();
  return arrangement.slice(0, 8).flatMap((section) => {
    const entries = section.entries.slice(0, 8).flatMap((id) => {
      if (!Object.hasOwn(destinations, id) || seen.has(id)) return [];
      if (id !== "preferences" && presentation.navigation?.[id] !== true) return [];
      seen.add(id);
      return [destinations[id]];
    });
    return entries.length
      ? [{ id: section.id, label: section.label.trim().slice(0, 60), entries }]
      : [];
  });
}
