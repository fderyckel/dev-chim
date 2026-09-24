import type { PreviewViewData } from "../ports/view-data";
import Link from "next/link";
import { InterfaceStateExplorer } from "./interface-state-explorer";

type UiPreviewProps = Readonly<{
  viewData: PreviewViewData;
}>;

export function UiPreview({ viewData }: UiPreviewProps) {
  return (
    <div className="l-page-stack">
      <header className="c-page-heading c-page-heading--preview">
        <div className="c-page-heading__copy">
          <span className="c-page-heading__eyebrow">Review surface</span>
          <h1 className="c-page-heading__title">UI preview</h1>
          <p className="c-page-heading__lede">
            Inspect the small set of interface primitives and public response states
            used by this synthetic prototype.
          </p>
        </div>
        <Link className="c-button c-button--quiet" href="/">
          <span className="c-button__icon" aria-hidden="true">
            ←
          </span>
          Return to Home
        </Link>
      </header>

      <aside className="c-boundary-banner" aria-label="Prototype boundary">
        <span className="c-boundary-banner__label">Synthetic review mode</span>
        <p className="c-boundary-banner__copy">
          Controls below change only this page’s in-memory example. They do not
          authenticate, authorize, save, or send data.
        </p>
      </aside>

      <section
        className="c-preview-section"
        id="interface-states"
        aria-labelledby="states-title"
      >
        <div className="c-preview-section__heading">
          <div className="c-preview-section__heading-copy">
            <p className="c-preview-section__eyebrow">Recovery language</p>
            <h2 className="c-preview-section__title" id="states-title">
              Interface states
            </h2>
            <p className="c-preview-section__description">
              Every state has a written label, a non-disclosing explanation, and a next
              step. Colour is supporting information only.
            </p>
          </div>
          <span className="c-status c-status--synthetic">8 public states</span>
        </div>
        <InterfaceStateExplorer states={viewData.states} />
      </section>

      <div className="l-preview-grid">
        <section className="c-preview-section" aria-labelledby="actions-title">
          <div className="c-preview-section__heading">
            <div className="c-preview-section__heading-copy">
              <p className="c-preview-section__eyebrow">Clear intent</p>
              <h2 className="c-preview-section__title" id="actions-title">
                Actions and links
              </h2>
            </div>
          </div>
          <div className="c-preview-stack">
            <a className="c-button c-button--primary" href="#form-example">
              Go to form example
              <span className="c-button__icon" aria-hidden="true">
                ↓
              </span>
            </a>
            <Link className="c-button c-button--secondary" href="/">
              Return to Home
            </Link>
            <button className="c-button c-button--quiet" type="button" disabled>
              Unavailable example
            </button>
            <p className="c-preview-stack__note">
              Disabled controls stay labelled and visually distinct. They are never
              hidden as an authorization technique.
            </p>
          </div>
        </section>

        <section
          className="c-preview-section"
          id="form-example"
          aria-labelledby="form-title"
        >
          <div className="c-preview-section__heading">
            <div className="c-preview-section__heading-copy">
              <p className="c-preview-section__eyebrow">Accessible defaults</p>
              <h2 className="c-preview-section__title" id="form-title">
                Form fields
              </h2>
            </div>
          </div>
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

            <button className="c-button c-button--primary" type="button" disabled>
              Saving is unavailable in UI-0
            </button>
          </form>
        </section>
      </div>

      <section className="c-preview-section" aria-labelledby="content-title">
        <div className="c-preview-section__heading">
          <div className="c-preview-section__heading-copy">
            <p className="c-preview-section__eyebrow">Progressive disclosure</p>
            <h2 className="c-preview-section__title" id="content-title">
              Content containers
            </h2>
          </div>
        </div>

        <div className="l-content-example-grid">
          <article className="c-example-card">
            <span className="c-status c-status--positive">Ready</span>
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
            <Link className="c-text-link" href="/">
              Return to Home
            </Link>
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
      </section>
    </div>
  );
}
