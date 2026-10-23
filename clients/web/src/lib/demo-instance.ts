import type { DemoDatedItem, DemoInstance, DemoState } from "../ports/demo-instance";

type Row = Record<string, string | number | boolean | readonly number[] | null>;
export type DemoPack = {
  schema_version: number;
  pack_id: string;
  tenant_id: string;
  synthetic: boolean;
  usage: string;
  reference_date: string;
  accounts: unknown[];
  authorization_grants: unknown[];
  records: Record<string, Row[]>;
};

const text = (row: Row, field: string) => {
  const value = row[field];
  if (typeof value !== "string") throw new Error("Invalid demo field");
  return value;
};
const find = (rows: Row[], id: string) => {
  const row = rows.find((item) => item.id === id);
  if (!row) throw new Error("Invalid demo reference");
  return row;
};
export function intervalState(from: string, until: string, on: string): DemoState {
  return on < from ? "Starts later" : on >= until ? "Ended" : "Current";
}
export function dateLabel(on: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${on}T00:00:00Z`));
}
function dayAfter(on: string) {
  const date = new Date(`${on}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}
export function intervalLabel(item: DemoDatedItem) {
  const through = new Date(`${item.until}T00:00:00Z`);
  through.setUTCDate(through.getUTCDate() - 1);
  return `${dateLabel(item.from)} to ${dateLabel(through.toISOString().slice(0, 10))}`;
}
export function projectDemo(pack: DemoPack): DemoInstance {
  const r = pack.records;
  const on = pack.reference_date;
  const institution = r.institutions[0];
  const year = r.academic_years[0];
  const college = institution.kind === "community_college";
  const person = (id: string) => find(r.people, id);
  const name = (id: string) => text(person(id), "display_name");
  const contactIds = [
    ...new Set(r.relationships.map((row) => text(row, "contact_person_id"))),
  ];
  const contactReference = (id: string) =>
    `C${String(contactIds.indexOf(id) + 1).padStart(3, "0")}`;
  const dated = (row: Row, label: string): DemoDatedItem => ({
    id: text(row, "id"),
    label,
    from: text(row, "effective_from"),
    until: text(row, "effective_until"),
    state: intervalState(text(row, "effective_from"), text(row, "effective_until"), on),
  });
  const sectionItem = (section: Row, row?: Row) => {
    const session = find(r.calendar_sessions, text(section, "calendar_session_id"));
    const dates = row ?? {
      ...section,
      effective_from: section.start_on,
      effective_until: dayAfter(text(section, "end_on")),
    };
    return dated(dates, `${text(section, "label")} · ${text(session, "label")}`);
  };
  const students = r.students.map((student, i) => {
    const enrolment = r.enrolments.find((e) => e.student_id === student.id);
    if (!enrolment) throw new Error("Missing demo enrolment");
    const programme = find(r.programmes, text(enrolment, "programme_id"));
    return {
      id: text(student, "id"),
      reference: `S${String(i + 1).padStart(3, "0")}`,
      name: name(text(student, "person_id")),
      level: text(student, "year_level"),
      programme: text(programme, "label"),
      enrolment: dated(enrolment, "Enrolment"),
      registers: r.placements
        .filter((row) => row.enrolment_id === enrolment.id)
        .map((row) =>
          dated(row, text(find(r.registers, text(row, "register_id")), "label")),
        ),
      sections: r.section_registrations
        .filter((row) => row.enrolment_id === enrolment.id)
        .map((row) => sectionItem(find(r.sections, text(row, "section_id")), row)),
      contacts: r.relationships
        .filter((row) => row.student_id === student.id)
        .map((row) => {
          const contact = person(text(row, "contact_person_id"));
          return {
            ...dated(row, text(row, "meaning").replaceAll("_", " ")),
            name: text(contact, "display_name"),
            reference: contactReference(text(contact, "id")),
            purpose: text(row, "purpose").replaceAll("_", " "),
            email: typeof contact.email === "string" ? contact.email : null,
          };
        }),
    };
  });
  return {
    packId: pack.pack_id,
    institutionId: text(institution, "id"),
    academicYearId: text(year, "id"),
    yearStart: text(year, "start_on"),
    yearEnd: text(year, "end_on"),
    locale: text(institution, "locale"),
    instructionalWeekdays: Array.isArray(year.instructional_weekdays)
      ? year.instructional_weekdays
      : [],
    institution: text(institution, "name"),
    location: `${text(institution, "city")} · ${text(institution, "country")}`,
    college,
    referenceDate: on,
    timeZone: text(year, "time_zone"),
    yearLabel: text(year, "label"),
    currentEnrolments: students.filter((s) => s.enrolment.state === "Current").length,
    students,
    contacts: contactIds.map((id) => ({
      id,
      reference: contactReference(id),
      name: name(id),
      email: typeof person(id).email === "string" ? (person(id).email as string) : null,
      learners: r.relationships
        .filter((row) => row.contact_person_id === id)
        .map((row) => {
          const student = students.find((s) => s.id === row.student_id);
          if (!student) throw new Error("Missing demo contact link");
          return {
            ...dated(
              row,
              `${student.name} · ${text(row, "meaning").replaceAll("_", " ")}`,
            ),
            reference: student.reference,
            purpose: text(row, "purpose").replaceAll("_", " "),
          };
        }),
    })),
    educators: r.educators.map((row, i) => ({
      id: text(row, "id"),
      reference: `E${String(i + 1).padStart(3, "0")}`,
      name: name(text(row, "person_id")),
      function: text(row, "function").replaceAll("_", " "),
      registers: r.teaching_assignments
        .filter((a) => a.educator_id === row.id)
        .map((a) =>
          dated(
            a,
            `${text(find(r.registers, text(a, "register_id")), "label")} · ${text(a, "responsibility").replaceAll("_", " ")}`,
          ),
        ),
      sections: r.sections
        .filter((s) => s.educator_id === row.id)
        .map((s) => sectionItem(s)),
    })),
    terms: r.periods.map((row) => ({
      id: text(row, "id"),
      label: text(row, "label"),
      from: text(row, "start_on"),
      through: text(row, "end_on"),
      scope: text(year, "label"),
    })),
    closures: r.closures.map((row) => ({
      id: text(row, "id"),
      label: text(row, "label"),
      from: text(row, "start_on"),
      through: text(row, "end_on"),
      scope: `${text(row, "scope").replaceAll("_", " ")} · ${text(row, "effect").replaceAll("_", " ")}`,
    })),
    events: r.events.map((row) => ({
      id: text(row, "id"),
      label: text(row, "label"),
      from: text(row, "on"),
      through: text(row, "on"),
      scope:
        text(row, "audience").replaceAll("_", " ") +
        (typeof row.calendar_session_id === "string"
          ? ` · ${text(find(r.calendar_sessions, row.calendar_session_id), "label")}`
          : ""),
    })),
  };
}
