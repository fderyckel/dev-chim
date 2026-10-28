import type { DemoSection } from "./demo-navigation";

export type DemoPageId = Exclude<DemoSection, "overview" | "apps">;
export type DemoLayoutSection = { id: string; label: string; items: DemoPageId[] };
export type DemoHomeLayout = {
  id: string;
  name: string;
  sections: DemoLayoutSection[];
};

export const demoPageIds: readonly DemoPageId[] = [
  "students",
  "contacts",
  "educators",
  "calendar",
];
export const temporaryLayoutNotice =
  "Preview only · resets on reload or institution switch";

export function defaultAppSections(): DemoLayoutSection[] {
  return [
    { id: "students-support", label: "Students & support", items: ["students"] },
    {
      id: "teaching-learning",
      label: "Teaching & learning",
      items: ["educators", "calendar"],
    },
  ];
}

export function defaultHomeLayout(id = "home-1"): DemoHomeLayout {
  return {
    id,
    name: "My Home",
    sections: [{ id: "quick-access", label: "Quick access", items: [...demoPageIds] }],
  };
}

export function copySections(sections: readonly DemoLayoutSection[]) {
  return sections.map((section) => ({ ...section, items: [...section.items] }));
}

export function validLayoutLabel(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.trim().length > 0 &&
    value.length <= 60 &&
    !/[<>]/.test(value) &&
    ![...value].some((character) => character.charCodeAt(0) < 32)
  );
}

export function validLayoutSections(value: unknown): value is DemoLayoutSection[] {
  if (!Array.isArray(value) || value.length > 8) return false;
  const ids = new Set<string>();
  const labels = new Set<string>();
  return value.every((section) => {
    if (
      !section ||
      typeof section !== "object" ||
      Object.keys(section).sort().join(",") !== "id,items,label"
    )
      return false;
    if (
      typeof section.id !== "string" ||
      !/^[a-z0-9-]{1,48}$/.test(section.id) ||
      ids.has(section.id) ||
      !validLayoutLabel(section.label)
    )
      return false;
    const label = section.label.trim().toLocaleLowerCase();
    if (
      labels.has(label) ||
      !Array.isArray(section.items) ||
      section.items.length > demoPageIds.length ||
      new Set(section.items).size !== section.items.length ||
      !section.items.every((item: unknown) => demoPageIds.includes(item as DemoPageId))
    )
      return false;
    ids.add(section.id);
    labels.add(label);
    return true;
  });
}

export function moveLayoutItem(
  sections: readonly DemoLayoutSection[],
  sourceId: string,
  item: DemoPageId,
  targetId: string,
) {
  const source = sections.find((section) => section.id === sourceId);
  const target = sections.find((section) => section.id === targetId);
  if (!source?.items.includes(item) || !target || target.items.includes(item))
    return copySections(sections);
  return sections.map((section) => ({
    ...section,
    items:
      section.id === sourceId
        ? section.items.filter((candidate) => candidate !== item)
        : section.id === targetId
          ? [...section.items, item]
          : [...section.items],
  }));
}

export function reorder<T>(items: readonly T[], index: number, direction: -1 | 1): T[] {
  const result = [...items];
  const next = index + direction;
  if (index < 0 || next < 0 || index >= items.length || next >= items.length)
    return result;
  [result[index], result[next]] = [result[next], result[index]];
  return result;
}

export function nextLayoutId(prefix: string, used: readonly string[]) {
  let index = 1;
  while (used.includes(`${prefix}-${index}`)) index += 1;
  return `${prefix}-${index}`;
}
