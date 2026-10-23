export type DemoState = "Current" | "Starts later" | "Ended";
export type DemoDatedItem = Readonly<{
  id: string;
  label: string;
  from: string;
  until: string;
  state: DemoState;
}>;
export type DemoContactLink = DemoDatedItem &
  Readonly<{
    name: string;
    reference: string;
    purpose: string;
    email: string | null;
  }>;
export type DemoStudent = Readonly<{
  id: string;
  reference: string;
  name: string;
  level: string;
  programme: string;
  enrolment: DemoDatedItem;
  registers: readonly DemoDatedItem[];
  sections: readonly DemoDatedItem[];
  contacts: readonly DemoContactLink[];
}>;
export type DemoContact = Readonly<{
  id: string;
  reference: string;
  name: string;
  email: string | null;
  learners: readonly (DemoDatedItem &
    Readonly<{ reference: string; purpose: string }>)[];
}>;
export type DemoEducator = Readonly<{
  id: string;
  reference: string;
  name: string;
  function: string;
  registers: readonly DemoDatedItem[];
  sections: readonly DemoDatedItem[];
}>;
export type DemoCalendarItem = Readonly<{
  id: string;
  label: string;
  from: string;
  through: string;
  scope: string;
}>;
export type DemoInstance = Readonly<{
  institution: string;
  location: string;
  college: boolean;
  referenceDate: string;
  timeZone: string;
  yearLabel: string;
  currentEnrolments: number;
  students: readonly DemoStudent[];
  contacts: readonly DemoContact[];
  educators: readonly DemoEducator[];
  terms: readonly DemoCalendarItem[];
  closures: readonly DemoCalendarItem[];
  events: readonly DemoCalendarItem[];
}>;
