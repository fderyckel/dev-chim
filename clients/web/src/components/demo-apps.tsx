"use client";

import { useRef, useState } from "react";
import Link from "next/link";
import { CalendarDays, GraduationCap, UsersRound, ArrowRight } from "lucide-react";
import { ActionButton } from "../design-system/components/actions";
import { demoHref } from "../lib/demo-institutions";
import { findDemoDestinations, type DemoApp } from "../lib/demo-navigation";

import {
  defaultAppSections,
  temporaryLayoutNotice,
  type DemoLayoutSection,
} from "../lib/demo-layout";
import { useDemoLayoutSession } from "./demo-layout-session";
import { DemoSectionEditor } from "./demo-section-editor";
import { DemoResetLayout } from "./demo-reset-layout";

const icons = {
  students: UsersRound,
  educators: GraduationCap,
  calendar: CalendarDays,
};

export function DemoApps({
  apps,
  packId,
}: {
  apps: readonly DemoApp[];
  packId: string;
}) {
  const [query, setQuery] = useState("");
  const session = useDemoLayoutSession(packId);
  const [draft, setDraft] = useState<DemoLayoutSection[] | null>(null);
  const [message, setMessage] = useState("");
  const toolbar = useRef<HTMLDivElement>(null);
  if (!session) return <p role="alert">Demo layout unavailable.</p>;
  const destinations = apps.flatMap((app) => app.destinations);
  const results = findDemoDestinations(apps, query, session.appSections);
  const finish = () =>
    requestAnimationFrame(() =>
      toolbar.current?.querySelector<HTMLButtonElement>("button")?.focus(),
    );
  if (draft)
    return (
      <DemoSectionEditor
        kind="apps"
        initialSections={draft}
        destinations={destinations}
        onCancel={() => {
          setDraft(null);
          setMessage("Draft discarded. App organization is unchanged.");
          finish();
        }}
        onApply={(sections) => {
          session.applyApps(sections);
          setDraft(null);
          setQuery("");
          setMessage(
            "App organization applied for this preview. Personal Home layouts are unchanged.",
          );
          finish();
        }}
      />
    );
  return (
    <div className="c-demo-apps">
      <div className="c-demo-layout-toolbar" ref={toolbar}>
        <ActionButton variant="secondary" onClick={() => setDraft(session.appSections)}>
          Organize apps
        </ActionButton>
        <DemoResetLayout
          label="Reset app organization"
          description="Replace this demo institution's app groups with their built-in arrangement. Personal Home layouts are not reset."
          onReset={() => {
            session.applyApps(defaultAppSections());
            setMessage("App organization reset for this preview.");
          }}
        />
        <span className="c-demo-muted">{temporaryLayoutNotice}</span>
      </div>
      <div className="c-demo-app-search">
        <label className="c-field">
          <span className="c-field__label">Find an app or page</span>
          <input
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Try contacts or calendar"
          />
        </label>
        {query ? (
          <ActionButton variant="secondary" onClick={() => setQuery("")}>
            Clear search
          </ActionButton>
        ) : null}
      </div>
      <p role="status" className="c-demo-layout-announcement">
        {query.trim()
          ? results.length
            ? `${results.length} ${results.length === 1 ? "page" : "pages"} found`
            : "No apps or pages match your search."
          : message}
      </p>
      {query.trim() ? (
        <>
          <ul className="c-demo-destination-results">
            {results.map(({ app, destination }) => (
              <li key={destination.id}>
                <Link
                  href={demoHref(destination.href, packId)}
                  className="c-demo-destination-link"
                >
                  <span>
                    <strong>{destination.label}</strong>
                    <span className="c-demo-muted">{app.label}</span>
                  </span>
                  <ArrowRight size={20} aria-hidden="true" />
                </Link>
              </li>
            ))}
          </ul>
        </>
      ) : (
        <div className="c-demo-app-groups">
          {session.appSections.length === 0 ? (
            <p>No app groups. Use Organize apps or All available pages.</p>
          ) : null}
          {session.appSections.map((group) => (
            <section
              className={`c-demo-app-group${group.items.length > 1 ? " c-demo-app-group--multiple" : ""}`}
              key={group.id}
              aria-label={group.label}
            >
              <h2>{group.label}</h2>
              <ul className="c-demo-app-grid">
                {group.items.map((pageId) => {
                  const app = apps.find((candidate) =>
                    candidate.destinations.some(
                      (destination) => destination.id === pageId,
                    ),
                  )!;
                  const destination = app.destinations.find(
                    (candidate) => candidate.id === pageId,
                  )!;
                  const Icon = icons[app.id];
                  const descriptionId = `demo-app-description-${group.id}-${pageId}`;
                  return (
                    <li key={pageId}>
                      <Link
                        className="c-demo-app-tile"
                        href={demoHref(destination.href, packId)}
                        aria-label={destination.label}
                        aria-describedby={descriptionId}
                      >
                        <span className="c-demo-app-icon">
                          <Icon size={28} strokeWidth={1.6} aria-hidden="true" />
                        </span>
                        <strong>{destination.label}</strong>
                        <span className="c-demo-muted" id={descriptionId}>
                          {pageId === "contacts"
                            ? "Contact relationships only"
                            : app.description}
                        </span>
                      </Link>
                    </li>
                  );
                })}
              </ul>
              {group.items.length === 0 ? (
                <p className="c-demo-muted">No shortcuts in this group.</p>
              ) : null}
            </section>
          ))}
        </div>
      )}
      <details className="c-demo-all-pages">
        <summary>All available pages</summary>
        <nav aria-label="All available pages">
          <ul>
            {destinations.map((destination) => (
              <li key={destination.id}>
                <Link href={demoHref(destination.href, packId)}>
                  {destination.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </details>
    </div>
  );
}
