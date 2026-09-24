import type { HomeViewData } from "../ports/view-data";
import Link from "next/link";

type HomeViewProps = Readonly<{
  viewData: HomeViewData;
}>;

export function HomeView({ viewData }: HomeViewProps) {
  return (
    <div className="l-page-stack">
      <header className="c-page-heading">
        <div className="c-page-heading__copy">
          <span className="c-page-heading__eyebrow">Today</span>
          <h1 className="c-page-heading__title">A clear place to begin</h1>
          <p className="c-page-heading__lede">
            Review what needs attention in this local experience prototype.
          </p>
        </div>
        <div className="c-page-heading__assurance" role="status">
          <span className="c-status c-status--positive">Prototype ready</span>
          <span className="c-page-heading__assurance-copy">
            Everything shown is deterministic and synthetic.
          </span>
        </div>
      </header>

      <section
        className="c-priority-card has-leading-icon"
        aria-labelledby="priority-title"
      >
        <div className="c-priority-card__symbol" aria-hidden="true">
          01
        </div>
        <div className="c-priority-card__body">
          <p className="c-priority-card__eyebrow">{viewData.priority.eyebrow}</p>
          <h2 className="c-priority-card__title" id="priority-title">
            {viewData.priority.title}
          </h2>
          <p className="c-priority-card__description">
            {viewData.priority.description}
          </p>
          <a
            className="c-button c-button--primary c-priority-card__action"
            href={viewData.priority.actionHref}
          >
            {viewData.priority.actionLabel}
            <span className="c-button__icon" aria-hidden="true">
              ↓
            </span>
          </a>
        </div>
        <p className="c-priority-card__note">
          Local review surface
          <span className="c-priority-card__note-detail">No record can be changed</span>
        </p>
      </section>

      <div className="l-page-grid">
        <section
          className="c-panel c-panel--attention"
          id="attention"
          aria-labelledby="attention-title"
        >
          <div className="c-panel__header">
            <div className="c-panel__heading-group">
              <p className="c-panel__eyebrow">Needs a person</p>
              <h2 className="c-panel__title" id="attention-title">
                Attention
              </h2>
            </div>
            <span className="c-status c-status--attention">
              {viewData.attention.length} items
            </span>
          </div>

          <ul className="c-item-list" aria-label="Synthetic attention items">
            {viewData.attention.map((item) => (
              <li className="c-item-row" key={item.id}>
                <span
                  className={`c-item-row__marker c-item-row__marker--${item.tone}`}
                  aria-hidden="true"
                />
                <span className="c-item-row__body">
                  <strong className="c-item-row__title">{item.title}</strong>
                  <span className="c-item-row__detail">{item.detail}</span>
                </span>
                <span className="c-item-row__status">{item.status}</span>
              </li>
            ))}
          </ul>

          <p className="c-panel__footnote">
            Example content only. These rows do not open a school workflow.
          </p>
        </section>

        <section className="c-panel" aria-labelledby="activity-title">
          <div className="c-panel__header">
            <div className="c-panel__heading-group">
              <p className="c-panel__eyebrow">Traceable and calm</p>
              <h2 className="c-panel__title" id="activity-title">
                Recent activity
              </h2>
            </div>
          </div>

          <ol className="c-activity-list">
            {viewData.activity.map((item) => (
              <li className="c-activity-row" key={item.id}>
                <span className="c-activity-row__line" aria-hidden="true" />
                <span className="c-activity-row__body">
                  <strong className="c-activity-row__label">{item.label}</strong>
                  <span className="c-activity-row__detail">{item.detail}</span>
                </span>
                <time className="c-activity-row__time">{item.time}</time>
              </li>
            ))}
          </ol>
        </section>
      </div>

      <aside className="c-prototype-notice" aria-labelledby="prototype-note-title">
        <span className="c-prototype-notice__icon" aria-hidden="true">
          i
        </span>
        <div className="c-prototype-notice__body">
          <h2 className="c-prototype-notice__title" id="prototype-note-title">
            This is an experience test, not working school software
          </h2>
          <p className="c-prototype-notice__copy">
            Use it to judge hierarchy, language, keyboard flow, responsive layout, and
            recovery guidance. It has no production data or authority.
          </p>
        </div>
        <Link className="c-button c-button--quiet" href="/ui-preview">
          Explore UI states
          <span className="c-button__icon" aria-hidden="true">
            →
          </span>
        </Link>
      </aside>
    </div>
  );
}
