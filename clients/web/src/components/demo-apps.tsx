"use client";

import { useState } from "react";
import Link from "next/link";
import { CalendarDays, GraduationCap, UsersRound, ArrowRight } from "lucide-react";
import { ActionButton } from "../design-system/components/actions";
import { demoHref } from "../lib/demo-institutions";
import { findDemoDestinations, type DemoApp } from "../lib/demo-navigation";

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
  const results = findDemoDestinations(apps, query);
  return (
    <div className="c-demo-apps">
      <div className="c-demo-app-search">
        <label className="c-field">
          <span className="c-field__label">Find an app or page</span>
          <input
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Try family contacts or calendar"
          />
        </label>
        {query ? (
          <ActionButton variant="secondary" onClick={() => setQuery("")}>
            Clear search
          </ActionButton>
        ) : null}
      </div>
      {query.trim() ? (
        <>
          <p role="status" className="c-demo-muted">
            {results.length
              ? `${results.length} ${results.length === 1 ? "page" : "pages"} found`
              : "No apps or pages match your search."}
          </p>
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
          {[...new Set(apps.map((app) => app.group))].map((group) => (
            <section
              className={`c-demo-app-group${apps.filter((app) => app.group === group).length > 1 ? " c-demo-app-group--multiple" : ""}`}
              key={group}
              aria-label={group}
            >
              <h2>{group}</h2>
              <ul className="c-demo-app-grid">
                {apps
                  .filter((app) => app.group === group)
                  .map((app) => {
                    const Icon = icons[app.id];
                    return (
                      <li key={app.id}>
                        <Link
                          className="c-demo-app-tile"
                          href={demoHref(app.destinations[0].href, packId)}
                          aria-label={app.label}
                          aria-describedby={`demo-app-description-${app.id}`}
                        >
                          <span className="c-demo-app-icon">
                            <Icon size={28} strokeWidth={1.6} aria-hidden="true" />
                          </span>
                          <strong>{app.label}</strong>
                          <span
                            className="c-demo-muted"
                            id={`demo-app-description-${app.id}`}
                          >
                            {app.description}
                          </span>
                        </Link>
                      </li>
                    );
                  })}
              </ul>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}
