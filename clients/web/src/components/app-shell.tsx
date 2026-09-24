import type { ReactNode } from "react";
import Link from "next/link";

import type { NavigationKey, PrototypeContext } from "../ports/view-data";

type AppShellProps = Readonly<{
  activePage: NavigationKey;
  context: PrototypeContext;
  children: ReactNode;
}>;

const navigation = [
  { key: "home" as const, label: "Home", href: "/" },
  { key: "preview" as const, label: "UI preview", href: "/ui-preview" },
];

export function AppShell({ activePage, context, children }: AppShellProps) {
  return (
    <div className="l-app-shell">
      <a className="c-skip-link" href="#main-content">
        Skip to main content
      </a>

      <header className="c-product-header">
        <div className="l-header-inner">
          <Link className="c-brand" href="/" aria-label="Chimwemwe home">
            <span className="c-brand__mark" aria-hidden="true">
              C
            </span>
            <span className="c-brand__wordmark">Chimwemwe</span>
          </Link>

          <div className="c-prototype-flag" role="status">
            <span className="c-prototype-flag__signal" aria-hidden="true" />
            Local prototype · synthetic data
          </div>

          <div className="c-account-control">
            <span className="c-account-control__avatar" aria-hidden="true">
              EX
            </span>
            <span className="c-account-control__copy">
              <span className="c-account-control__label">Example account</span>
              <span className="c-account-control__meta">
                Controls unavailable in UI-0
              </span>
            </span>
          </div>
        </div>
      </header>

      <aside className="l-context-bar" aria-label="Viewing context">
        <div className="l-context-bar__inner">
          <div className="c-context-summary">
            <span className="c-context-summary__eyebrow">Viewing context</span>
            <strong className="c-context-summary__name">{context.tenantName}</strong>
            <span className="c-status c-status--synthetic c-context-summary__status">
              Synthetic tenant
            </span>
          </div>
          <div className="c-connection-summary" aria-label="Prototype status">
            <span className="c-connection-summary__date">{context.dateLabel}</span>
            <span className="c-connection-summary__state">
              {context.connectionLabel}
            </span>
          </div>
        </div>
      </aside>

      <div className="l-body-shell">
        <nav className="c-primary-nav" aria-label="Primary navigation">
          <ul className="c-primary-nav__list">
            {navigation.map((item) => (
              <li className="c-primary-nav__item" key={item.key}>
                <Link
                  className={`c-primary-nav__link${
                    activePage === item.key ? " is-selected" : ""
                  }`}
                  href={item.href}
                  aria-current={activePage === item.key ? "page" : undefined}
                >
                  <span className="c-primary-nav__icon" aria-hidden="true">
                    {item.key === "home" ? "⌂" : "◫"}
                  </span>
                  {item.label}
                </Link>
              </li>
            ))}
          </ul>

          <div className="c-nav-note">
            <span className="c-nav-note__label">Experience boundary</span>
            <p className="c-nav-note__copy">
              Navigation does not imply access. Production authorization remains
              server-side.
            </p>
          </div>
        </nav>

        <main className="l-main-content" id="main-content" tabIndex={-1}>
          {children}
        </main>
      </div>

      <footer className="c-product-footer">
        <p className="c-product-footer__copy">
          UI-0 local experience foundation · synthetic fixtures only · no writes,
          authentication, storage, or server connection
        </p>
      </footer>
    </div>
  );
}
