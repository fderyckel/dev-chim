export const demoInstitutions = [
  { id: "bangkok-international", label: "Bangkok · International school" },
  { id: "us-community-college", label: "America · Community college" },
  { id: "hong-kong-kindergarten", label: "Hong Kong · Kindergarten" },
  { id: "england-independent", label: "England · Private school" },
] as const;

export function isDemoInstitution(value: unknown): value is string {
  return demoInstitutions.some((institution) => institution.id === value);
}

export function demoHref(path: string, packId: string) {
  return `${path}?${new URLSearchParams({ demo: packId })}`;
}
