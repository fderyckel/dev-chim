import type { HomeViewData } from "../ports/view-data";
import { ActionLink } from "../design-system/components/actions";
import { PageHeading } from "../design-system/components/page-heading";
import { Panel } from "../design-system/components/panel";
import { StatusBadge } from "../design-system/components/status-badge";

type HomeViewProps = Readonly<{
  viewData: HomeViewData;
}>;

export function HomeView({ viewData }: HomeViewProps) {
  return (
    <div className="l-page-stack">
      <PageHeading
        eyebrow="Today"
        title="A clear place to begin"
        description="Review what needs attention in this local experience prototype."
        aside={
          <>
            <StatusBadge tone="positive">Prototype ready</StatusBadge>
            <span className="c-page-heading__assurance-copy">
              Everything shown is deterministic and synthetic.
            </span>
          </>
        }
      />

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
          <ActionLink href={viewData.priority.actionHref} icon="down" variant="primary">
            {viewData.priority.actionLabel}
          </ActionLink>
        </div>
        <p className="c-priority-card__note">
          Local review surface
          <span className="c-priority-card__note-detail">No record can be changed</span>
        </p>
      </section>

      <div className="l-page-grid">
        <Panel
          eyebrow="Needs a person"
          title="Attention"
          titleId="attention-title"
          id="attention"
          tone="attention"
          badge={
            <StatusBadge tone="attention">
              {viewData.attention.length} items
            </StatusBadge>
          }
          footer="Example content only. These rows do not open a school workflow."
        >
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
        </Panel>

        <Panel
          eyebrow="Traceable and calm"
          title="Recent activity"
          titleId="activity-title"
        >
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
        </Panel>
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
        <ActionLink href="/ui-preview" icon="forward" variant="quiet">
          Explore UI states
        </ActionLink>
      </aside>
    </div>
  );
}
