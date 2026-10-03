import type { PreviewViewData } from "../ports/view-data";
import { ActionButton, ActionLink } from "../design-system/components/actions";
import { ExperienceProfilePreview } from "../design-system/components/experience-profile-preview";
import { PageHeading } from "../design-system/components/page-heading";
import { Panel } from "../design-system/components/panel";
import { StatusBadge } from "../design-system/components/status-badge";
import { InterfaceStateExplorer } from "./interface-state-explorer";

type UiPreviewProps = Readonly<{
  viewData: PreviewViewData;
}>;

export function UiPreview({ viewData }: UiPreviewProps) {
  return (
    <div className="l-page-stack">
      <PageHeading
        eyebrow="Review surface"
        title="UI preview"
        description="Inspect the small set of interface primitives and public response states used by this synthetic prototype."
        aside={
          <ActionLink href="/" icon="back" iconPosition="before" variant="quiet">
            Return to Home
          </ActionLink>
        }
      />

      <aside className="c-boundary-banner" aria-label="Prototype boundary">
        <span className="c-boundary-banner__label">Synthetic review mode</span>
        <p className="c-boundary-banner__copy">
          Controls below change only this page’s in-memory example. They do not
          authenticate, authorize, save, or send data.
        </p>
      </aside>

      <Panel
        eyebrow="Governed choice"
        title="Experience profiles"
        titleId="profiles-title"
        description="Compare three complete profiles. The information hierarchy, component behavior, and status meaning stay fixed."
        badge={<StatusBadge tone="information">Local preview only</StatusBadge>}
      >
        <ExperienceProfilePreview />
      </Panel>

      <Panel
        eyebrow="Recovery language"
        title="Interface states"
        titleId="states-title"
        id="interface-states"
        description="Every state has a written label, a non-disclosing explanation, and a next step. Colour is supporting information only."
        badge={<StatusBadge tone="information">8 public states</StatusBadge>}
      >
        <InterfaceStateExplorer states={viewData.states} />
      </Panel>

      <div className="l-preview-grid">
        <Panel eyebrow="Clear intent" title="Actions and links" titleId="actions-title">
          <div className="c-preview-stack">
            <ActionLink href="#form-example" icon="down" variant="primary">
              Go to form example
            </ActionLink>
            <ActionLink href="/" variant="secondary">
              Return to Home
            </ActionLink>
            <ActionButton variant="quiet" disabled>
              Unavailable example
            </ActionButton>
            <p className="c-preview-stack__note">
              Disabled controls stay labelled and visually distinct. They are never
              hidden as an authorization technique.
            </p>
          </div>
        </Panel>

        <Panel
          eyebrow="Accessible defaults"
          title="Form fields"
          titleId="form-title"
          id="form-example"
        >
          <form className="c-form" aria-label="Synthetic form example">
            <div className="c-field">
              <label className="c-field__label" htmlFor="example-reference">
                Example reference
              </label>
              <span className="c-field__hint" id="reference-hint">
                Use a clear local label. No value is sent or saved.
              </span>
              <input
                className="c-input"
                id="example-reference"
                name="example-reference"
                defaultValue="EXAMPLE-024"
                aria-describedby="reference-hint"
              />
            </div>

            <div className="c-field has-error">
              <label className="c-field__label" htmlFor="example-note">
                Review note <span className="c-field__required">(required)</span>
              </label>
              <span className="c-field__hint" id="note-hint">
                This static error demonstrates direct, written validation.
              </span>
              <textarea
                className="c-input c-input--textarea has-error"
                id="example-note"
                name="example-note"
                aria-invalid="true"
                aria-describedby="note-hint note-error"
                defaultValue="Too short"
              />
              <span className="c-field__error" id="note-error">
                Add enough detail for another person to understand the note.
              </span>
            </div>

            <ActionButton disabled variant="primary">
              Saving is unavailable in UI-0
            </ActionButton>
          </form>
        </Panel>
      </div>

      <Panel
        eyebrow="Progressive disclosure"
        title="Content containers"
        titleId="content-title"
      >
        <div className="l-content-example-grid">
          <article className="c-example-card">
            <StatusBadge tone="positive">Ready</StatusBadge>
            <h3 className="c-example-card__title">A focused card</h3>
            <p className="c-example-card__copy">
              Cards group one idea. They do not turn every fact into a dashboard tile.
            </p>
          </article>

          <div className="c-empty-state">
            <span className="c-empty-state__symbol" aria-hidden="true">
              ○
            </span>
            <h3 className="c-empty-state__title">No examples here yet</h3>
            <p className="c-empty-state__copy">
              Empty states explain what is absent and offer a safe route back.
            </p>
            <ActionLink href="/" variant="quiet">
              Return to Home
            </ActionLink>
          </div>

          <div className="c-skeleton-card is-loading" aria-busy="true">
            <span className="u-visually-hidden">
              Loading a synthetic content example
            </span>
            <span className="c-skeleton-card__line c-skeleton-card__line--short" />
            <span className="c-skeleton-card__line" />
            <span className="c-skeleton-card__line" />
            <span className="c-skeleton-card__line c-skeleton-card__line--medium" />
          </div>
        </div>
      </Panel>
    </div>
  );
}
