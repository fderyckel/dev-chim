import type { ReactNode } from "react";
import Link from "next/link";
import { House, LayoutGrid, ChevronDown } from "lucide-react";
import { ActionButton } from "../design-system/components/actions";
import { dateLabel } from "../lib/demo-instance";
import { demoHref, demoInstitutions } from "../lib/demo-institutions";
import { demoNavigation, type DemoSection } from "../lib/demo-navigation";
import type { DemoInstance } from "../ports/demo-instance";

export function DemoShell({
  data,
  section,
  children,
}: {
  data: DemoInstance;
  section: DemoSection;
  children: ReactNode;
}) {
  const { home, appsPage, apps, destinations } = demoNavigation(data.college);
  const page = destinations.find((destination) => destination.id === section)!;
  const app = apps.find((candidate) =>
    candidate.destinations.some((destination) => destination.id === section),
  );
  const href = (path: string) => demoHref(path, data.packId);
  const workspaceLinks = app ? (
    <nav aria-label="Workspace navigation">
      <ul className="c-primary-nav__list">
        {app.destinations.map((destination) => (
          <li className="c-primary-nav__item" key={destination.id}>
            <Link
              href={href(destination.href)}
              className={`c-primary-nav__link${section === destination.id ? " is-selected" : ""}`}
              aria-current={section === destination.id ? "page" : undefined}
            >
              {destination.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  ) : null;
  return (
    <div className="l-app-shell c-demo-shell">
      <a className="c-skip-link" href="#main-content">
        Skip to main content
      </a>
      <header className="c-product-header">
        <div className="l-header-inner">
          <Link href={href("/")} className="c-brand" aria-label="Chimwemwe home">
            <span className="c-brand__mark" aria-hidden="true">
              C
            </span>
            <span className="c-brand__wordmark">Chimwemwe</span>
          </Link>
          <nav className="c-demo-global-nav" aria-label="Primary navigation">
            {[home, appsPage].map((destination) => {
              const Icon = destination.id === "overview" ? House : LayoutGrid;
              return (
                <Link
                  key={destination.id}
                  href={href(destination.href)}
                  className={`c-demo-global-link${section === destination.id ? " is-selected" : ""}`}
                  aria-current={section === destination.id ? "page" : undefined}
                >
                  <Icon size={18} aria-hidden="true" />
                  {destination.label}
                </Link>
              );
            })}
          </nav>
          <span className="c-prototype-flag">
            Local demo · fictional data · read only
          </span>
        </div>
      </header>
      <aside className="l-context-bar" aria-label="Institution">
        <div className="l-context-bar__inner">
          <div className="c-context-summary">
            <strong className="c-context-summary__name">{data.institution}</strong>
            <span className="c-demo-muted">
              {data.location} · {data.yearLabel}
            </span>
            <span className="c-demo-muted">
              As of {dateLabel(data.referenceDate)} · {data.timeZone}
            </span>
          </div>
          <form
            key={`${data.packId}:${section}`}
            action={page.href}
            method="get"
            autoComplete="off"
            className="c-demo-institution-choice"
          >
            <label>
              Demo institution
              <select name="demo" defaultValue={data.packId}>
                {demoInstitutions.map((institution) => (
                  <option key={institution.id} value={institution.id}>
                    {institution.label}
                  </option>
                ))}
              </select>
            </label>
            <ActionButton type="submit" variant="secondary">
              Switch
            </ActionButton>
          </form>
        </div>
      </aside>
      <div className={`l-body-shell c-demo-body${app ? " has-workspace" : ""}`}>
        {app ? (
          <>
            <aside className="c-demo-workspace-desktop">
              <p className="c-demo-workspace-caption">Workspace</p>
              <h2>{app.label}</h2>
              {workspaceLinks}
              <Link className="c-demo-back-apps" href={href(appsPage.href)}>
                All apps
              </Link>
            </aside>
            <details key={section} className="c-demo-workspace-mobile">
              <summary>
                <span>
                  {app.label}
                  {app.label !== page.label ? ` / ${page.label}` : ""}
                </span>
                <span className="c-demo-workspace-toggle">
                  Pages <ChevronDown size={18} aria-hidden="true" />
                </span>
              </summary>
              {workspaceLinks}
            </details>
          </>
        ) : null}
        <main id="main-content" tabIndex={-1} className="l-main-content">
          {app ? (
            <nav className="c-demo-breadcrumb" aria-label="Breadcrumb">
              <ol>
                <li>
                  <Link href={href(appsPage.href)}>Apps</Link>
                </li>
                {app.label !== page.label ? (
                  <li>
                    <Link href={href(app.destinations[0].href)}>{app.label}</Link>
                  </li>
                ) : null}
                <li aria-current="page">{page.label}</li>
              </ol>
            </nav>
          ) : null}
          {children}
        </main>
      </div>
      <footer className="c-product-footer">
        <p className="c-product-footer__copy">
          Fictional demo · fixed example dates · read only
        </p>
      </footer>
    </div>
  );
}
