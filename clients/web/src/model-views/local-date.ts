const millisecondsPerDay = 86_400_000;
const isoDatePattern = /^(\d{4})-(\d{2})-(\d{2})$/;

export function parseLocalDate(value: string): number | null {
  const match = isoDatePattern.exec(value);
  if (!match) return null;

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const timestamp = Date.UTC(year, month - 1, day);
  const parsed = new Date(timestamp);

  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    return null;
  }

  return timestamp / millisecondsPerDay;
}

export function formatLocalDate(value: string): string {
  const day = parseLocalDate(value);
  if (day === null) return value;

  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(day * millisecondsPerDay));
}

export function toIsoLocalDate(day: number): string {
  return new Date(day * millisecondsPerDay).toISOString().slice(0, 10);
}

export function monthKey(value: string): string | null {
  const day = parseLocalDate(value);
  return day === null ? null : toIsoLocalDate(day).slice(0, 7);
}

export function addMonths(value: string, delta: number): string {
  const day = parseLocalDate(`${value.slice(0, 7)}-01`);
  if (day === null) return value;
  const date = new Date(day * millisecondsPerDay);
  date.setUTCMonth(date.getUTCMonth() + delta);
  return date.toISOString().slice(0, 7);
}

export function monthLabel(value: string): string {
  const day = parseLocalDate(`${value}-01`);
  if (day === null) return value;
  return new Intl.DateTimeFormat("en-GB", {
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(day * millisecondsPerDay));
}

export function monthDays(value: string): ReadonlyArray<number | null> {
  const first = parseLocalDate(`${value}-01`);
  if (first === null) return [];

  const firstDate = new Date(first * millisecondsPerDay);
  const mondayOffset = (firstDate.getUTCDay() + 6) % 7;
  const nextMonth = new Date(
    Date.UTC(firstDate.getUTCFullYear(), firstDate.getUTCMonth() + 1, 1),
  );
  const count = Math.round(nextMonth.getTime() / millisecondsPerDay - first);
  const cells: Array<number | null> = Array.from({ length: mondayOffset }, () => null);

  for (let index = 0; index < count; index += 1) cells.push(first + index);
  while (cells.length % 7 !== 0) cells.push(null);
  return cells;
}
