"use client";

import { useState, type ReactNode } from "react";
import Link from "next/link";

import { ActionButton, ActionLink } from "../design-system/components/actions";
import { PageHeading } from "../design-system/components/page-heading";
import { Panel } from "../design-system/components/panel";
import { StatusBadge } from "../design-system/components/status-badge";
import { dateLabel, intervalLabel } from "../lib/demo-instance";
import type {
  DemoCalendarItem,
  DemoDatedItem,
  DemoInstance,
} from "../ports/demo-instance";

const titles = (college: boolean) => [
  ["overview", "Overview", "/"],
  ["students", "Students", "/demo/students"],
  ["contacts", college ? "Contacts" : "Families & guardians", "/demo/contacts"],
  ["educators", college ? "Instructors" : "Educators", "/demo/educators"],
  ["calendar", "Calendar", "/demo/calendar"],
];

function State({
  item,
  enrolment = false,
}: {
  item: DemoDatedItem;
  enrolment?: boolean;
}) {
  return (
    <StatusBadge
      tone={
        item.state === "Current"
          ? "positive"
          : item.state === "Starts later"
            ? "information"
            : "neutral"
      }
    >
      {enrolment && item.state === "Current" ? "Enrolled" : item.state}
    </StatusBadge>
  );
}

function DatedList({
  items,
  empty,
}: {
  items: readonly DemoDatedItem[];
  empty: string;
}) {
  if (!items.length) return <p>{empty}</p>;
  return (
    <ul className="c-demo-list">
      {items.map((item) => (
        <li key={item.id}>
          <strong>{item.label}</strong> <State item={item} />
          <p className="c-demo-muted">{intervalLabel(item)}</p>
        </li>
      ))}
    </ul>
  );
}

function Directory<T extends { id: string; name: string; reference: string }>({
  items,
  render,
  levels,
  levelOf,
  noun,
}: {
  items: readonly T[];
  render: (item: T) => ReactNode;
  levels?: readonly string[];
  levelOf?: (item: T) => string;
  noun: string;
}) {
  const [query, setQuery] = useState("");
  const [level, setLevel] = useState("");
  const [page, setPage] = useState(0);
  const filtered = items.filter(
    (item) =>
      `${item.name} ${item.reference}`
        .toLocaleLowerCase()
        .includes(query.toLocaleLowerCase()) &&
      (!level || levelOf?.(item) === level),
  );
  const size = 12;
  const range = filtered.slice(page * size, (page + 1) * size);
  return (
    <div className="c-demo-directory">
      <div className="c-demo-filters">
        <label className="c-field">
          <span className="c-field__label">Search {noun}</span>
          <input
            type="search"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setPage(0);
            }}
          />
        </label>
        {levels ? (
          <label className="c-field">
            <span className="c-field__label">Year level</span>
            <select
              value={level}
              onChange={(e) => {
                setLevel(e.target.value);
                setPage(0);
              }}
            >
              <option value="">All levels</option>
              {levels.map((value) => (
                <option key={value}>{value}</option>
              ))}
            </select>
          </label>
        ) : null}
      </div>
      <p role="status" className="c-demo-muted">
        {filtered.length
          ? `${page * size + 1}–${page * size + range.length} of ${filtered.length} ${noun}`
          : `No ${noun} match your search.`}
      </p>
      <div className="c-demo-records">
        {range.map((item) => (
          <div key={item.id}>{render(item)}</div>
        ))}
      </div>
      {filtered.length > size ? (
        <nav className="c-demo-pagination" aria-label={`${noun} pages`}>
          <ActionButton
            variant="secondary"
            disabled={page === 0}
            onClick={() => setPage(page - 1)}
          >
            Previous
          </ActionButton>
          <span>
            Page {page + 1} of {Math.ceil(filtered.length / size)}
          </span>
          <ActionButton
            variant="secondary"
            disabled={(page + 1) * size >= filtered.length}
            onClick={() => setPage(page + 1)}
          >
            Next
          </ActionButton>
        </nav>
      ) : null}
    </div>
  );
}

function CalendarList({ items }: { items: readonly DemoCalendarItem[] }) {
  return (
    <ul className="c-demo-list">
      {[...items]
        .sort((a, b) => a.from.localeCompare(b.from))
        .map((item) => (
          <li key={item.id}>
            <strong>{item.label}</strong>
            <p>
              {dateLabel(item.from)}
              {item.through !== item.from ? ` – ${dateLabel(item.through)}` : ""}
            </p>
            <p className="c-demo-muted">{item.scope}</p>
          </li>
        ))}
    </ul>
  );
}

export function DemoInstanceView({
  data,
  section,
}: {
  data: DemoInstance;
  section: string;
}) {
  const navigation = titles(data.college);
  const title = navigation.find(([key]) => key === section)?.[1] ?? "Overview";
  const contactLabel = data.college ? "contacts" : "family contacts";
  return (
    <div className="l-app-shell c-demo-shell">
      <a className="c-skip-link" href="#main-content">
        Skip to main content
      </a>
      <header className="c-product-header">
        <div className="l-header-inner">
          <Link href="/" className="c-brand" aria-label="Chimwemwe home">
            <span className="c-brand__mark" aria-hidden="true">
              C
            </span>
            <span className="c-brand__wordmark">Chimwemwe</span>
          </Link>
          <span className="c-prototype-flag">
            Local demo · fictional data · read only
          </span>
        </div>
      </header>
      <aside className="l-context-bar" aria-label="Institution">
        <div className="l-context-bar__inner">
          <div className="c-context-summary">
            <strong className="c-context-summary__name">{data.institution}</strong>
            <span>{data.location}</span>
          </div>
          <p className="c-demo-muted">
            As of {dateLabel(data.referenceDate)} · {data.timeZone}
          </p>
        </div>
      </aside>
      <div className="l-body-shell">
        <nav className="c-primary-nav" aria-label="Primary navigation">
          <ul className="c-primary-nav__list">
            {navigation.map(([key, label, href]) => (
              <li className="c-primary-nav__item" key={key}>
                <Link
                  href={href}
                  className={`c-primary-nav__link${section === key ? " is-selected" : ""}`}
                  aria-current={section === key ? "page" : undefined}
                >
                  {label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
        <main id="main-content" tabIndex={-1} className="l-main-content">
          <div className="l-page-stack">
            <PageHeading
              eyebrow={data.yearLabel}
              title={section === "overview" ? "Your institution at a glance" : title}
              description={
                section === "overview"
                  ? "Explore the people and calendar in this fictional institution."
                  : `As of ${dateLabel(data.referenceDate)}`
              }
            />
            {section === "overview" ? (
              <>
                <div className="c-demo-stats">
                  {[
                    [
                      "students",
                      `${data.currentEnrolments}`,
                      "enrolled",
                      `${data.students.length} students in this demo`,
                    ],
                    [
                      "contacts",
                      `${data.contacts.length}`,
                      contactLabel,
                      "Distinct people; contact links only",
                    ],
                    [
                      "educators",
                      `${data.educators.length}`,
                      data.college ? "instructors" : "educators & support staff",
                      "Register and subject responsibilities",
                    ],
                  ].map(([key, count, label, detail]) => (
                    <Link key={key} className="c-demo-stat" href={`/demo/${key}`}>
                      <strong>{count}</strong>
                      <span>{label}</span>
                      <span className="c-demo-muted">{detail}</span>
                    </Link>
                  ))}
                </div>
                <Panel
                  title="Academic calendar"
                  titleId="demo-year"
                  eyebrow={data.timeZone}
                  footer={
                    <ActionLink href="/demo/calendar" variant="secondary">
                      View calendar
                    </ActionLink>
                  }
                >
                  <CalendarList items={data.terms} />
                </Panel>
              </>
            ) : null}
            {section === "students" ? (
              <Directory
                items={data.students}
                noun="students"
                levels={
                  data.college
                    ? undefined
                    : [...new Set(data.students.map((s) => s.level))]
                }
                levelOf={(s) => s.level}
                render={(student) => (
                  <details className="c-demo-record">
                    <summary>
                      <span>
                        <strong>{student.name}</strong>
                        <span className="c-demo-muted">
                          {student.reference} ·{" "}
                          {data.college ? student.programme : student.level}
                        </span>
                      </span>
                      <State item={student.enrolment} enrolment />
                    </summary>
                    <div className="c-demo-detail">
                      <p>
                        <strong>Programme:</strong> {student.programme}
                      </p>
                      <p>
                        <strong>Enrolment:</strong> {intervalLabel(student.enrolment)}
                      </p>
                      {!data.college ? (
                        <>
                          <h2>Daily register</h2>
                          <DatedList
                            items={student.registers}
                            empty="No register placement recorded."
                          />
                          {!student.registers.some((r) => r.state === "Current") ? (
                            <p>No current register placement.</p>
                          ) : null}
                        </>
                      ) : null}
                      <h2>{data.college ? "Course sections" : "Subject groups"}</h2>
                      <DatedList
                        items={student.sections}
                        empty={
                          data.college
                            ? "No course sections recorded."
                            : "No subject groups recorded."
                        }
                      />
                      <h2>{data.college ? "Contacts" : "Family contacts"}</h2>
                      {student.contacts.length ? (
                        <ul className="c-demo-list">
                          {student.contacts.map((contact) => (
                            <li key={contact.id}>
                              <strong>{contact.name}</strong> · {contact.reference}{" "}
                              <State item={contact} />
                              <p>
                                {contact.label} · {contact.purpose}
                              </p>
                              <p>{contact.email ?? "No email recorded"}</p>
                              <p className="c-demo-muted">{intervalLabel(contact)}</p>
                            </li>
                          ))}
                        </ul>
                      ) : (
                        <p>No contact recorded.</p>
                      )}
                      <p className="c-demo-muted">
                        Contact links do not grant collection, disclosure, messaging or
                        account access.
                      </p>
                    </div>
                  </details>
                )}
              />
            ) : null}
            {section === "contacts" ? (
              <>
                <p className="c-demo-muted">
                  Contact links only. Collection, disclosure, messaging and account
                  access are not granted.
                </p>
                <Directory
                  items={data.contacts}
                  noun={contactLabel}
                  render={(contact) => (
                    <details className="c-demo-record">
                      <summary>
                        <span>
                          <strong>{contact.name}</strong>
                          <span className="c-demo-muted">
                            {contact.reference} · {contact.email ?? "No email recorded"}
                          </span>
                        </span>
                      </summary>
                      <div className="c-demo-detail">
                        <h2>Linked students</h2>
                        <ul className="c-demo-list">
                          {contact.learners.map((learner) => (
                            <li key={learner.id}>
                              <strong>{learner.label}</strong> · {learner.reference}{" "}
                              <State item={learner} />
                              <p>{learner.purpose}</p>
                              <p className="c-demo-muted">{intervalLabel(learner)}</p>
                            </li>
                          ))}
                        </ul>
                      </div>
                    </details>
                  )}
                />
              </>
            ) : null}
            {section === "educators" ? (
              <Directory
                items={data.educators}
                noun={data.college ? "instructors" : "educators"}
                render={(educator) => (
                  <details className="c-demo-record">
                    <summary>
                      <span>
                        <strong>{educator.name}</strong>
                        <span className="c-demo-muted">
                          {educator.reference} · {educator.function}
                        </span>
                      </span>
                    </summary>
                    <div className="c-demo-detail">
                      {!data.college ? (
                        <>
                          <h2>Register responsibilities</h2>
                          <DatedList
                            items={educator.registers}
                            empty="No register responsibility recorded."
                          />
                        </>
                      ) : null}
                      <h2>{data.college ? "Course sections" : "Subject teaching"}</h2>
                      <DatedList
                        items={educator.sections}
                        empty="No subject teaching recorded."
                      />
                    </div>
                  </details>
                )}
              />
            ) : null}
            {section === "calendar" ? (
              <>
                <Panel
                  title="Teaching periods"
                  titleId="demo-terms"
                  eyebrow={data.yearLabel}
                >
                  <CalendarList items={data.terms} />
                </Panel>
                <Panel
                  title="Student closures"
                  titleId="demo-closures"
                  eyebrow="No instruction"
                >
                  <CalendarList items={data.closures} />
                </Panel>
                <Panel
                  title="Events"
                  titleId="demo-events"
                  eyebrow="Information only"
                  description="Events do not change teaching days."
                >
                  <CalendarList items={data.events} />
                </Panel>
              </>
            ) : null}
          </div>
        </main>
      </div>
      <footer className="c-product-footer">
        <p className="c-product-footer__copy">
          Fictional demo · fixed example dates · restart the demo to choose another
          institution
        </p>
      </footer>
    </div>
  );
}
