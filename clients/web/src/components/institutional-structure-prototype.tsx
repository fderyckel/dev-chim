import type {
  InstitutionalStructureViewData,
  InstitutionalUnitNode,
  MoveImpact,
} from "../ports/view-data";

type InstitutionalStructurePrototypeProps = Readonly<{
  viewData: InstitutionalStructureViewData;
}>;

function UnitTree({
  units,
  level,
  selectedId,
}: Readonly<{
  units: ReadonlyArray<InstitutionalUnitNode>;
  level: number;
  selectedId: string;
}>) {
  return (
    <ul aria-label={level === 1 ? "Institutional containment" : undefined}>
      {units.map((unit) => {
        const hasChildren = unit.children.length > 0;
        const selected = unit.id === selectedId;

        return (
          <li className="c-structure-tree__item" key={unit.id}>
            <div
              className={`c-structure-tree__row${selected ? " is-selected" : ""}`}
              aria-current={selected ? "true" : undefined}
            >
              <span className="c-structure-tree__branch" aria-hidden="true">
                {hasChildren ? "−" : "·"}
              </span>
              <span className="c-structure-tree__copy">
                <strong>{unit.name}</strong>
                <span>
                  {unit.localLabel} · {unit.code}
                </span>
              </span>
              <span
                className={`c-status${
                  unit.status === "closed" ? " c-status--attention" : ""
                }`}
              >
                {unit.status === "closed" ? "Closed" : "Current"}
              </span>
            </div>
            {hasChildren ? (
              <UnitTree
                units={unit.children}
                level={level + 1}
                selectedId={selectedId}
              />
            ) : null}
          </li>
        );
      })}
    </ul>
  );
}

const impactLabels: Record<MoveImpact["outcome"], string> = {
  unchanged: "Unchanged",
  requires_reconciliation: "Requires reconciliation",
  blocks_move: "Blocks move",
};

const classificationLabels = {
  institution: "Institution",
  organizational_unit: "Organizational unit",
} as const;

export function InstitutionalStructurePrototype({
  viewData,
}: InstitutionalStructurePrototypeProps) {
  return (
    <div className="l-page-stack">
      <header className="c-page-heading">
        <div className="c-page-heading__copy">
          <p className="c-page-heading__eyebrow">ADR 0025 · L0 review prototype</p>
          <h1 className="c-page-heading__title">Institutional structure</h1>
          <p className="c-page-heading__lede">
            Review several roots, nested units, shared sites, affiliations, and a move
            impact without treating the hierarchy as authority.
          </p>
        </div>
        <div className="c-page-heading__assurance">
          <span className="c-status c-status--synthetic">
            Read-only synthetic evidence
          </span>
          <span className="c-page-heading__assurance-copy">
            No record, access grant, module, report, or placement can change here.
          </span>
        </div>
      </header>

      <section className="c-boundary-banner" aria-label="Hierarchy boundary">
        <span className="c-boundary-banner__label">Containment only</span>
        <p className="c-boundary-banner__copy">
          A parent, visible ancestor, or selected unit never grants access, widens a
          report, applies configuration, activates a module, selects placement, or turns
          a site into an institution.
        </p>
      </section>

      <div className="l-structure-grid">
        <section className="c-panel" aria-labelledby="structure-tree-title">
          <div className="c-panel__header">
            <div>
              <p className="c-panel__eyebrow">Canonical containment</p>
              <h2 className="c-panel__title" id="structure-tree-title">
                Three independent roots
              </h2>
            </div>
            <span className="c-status">Bounded view</span>
          </div>
          <div className="c-structure-tree">
            <UnitTree
              units={viewData.roots}
              level={1}
              selectedId={viewData.selectedUnit.id}
            />
          </div>
          <p className="c-panel__footnote">
            This is a fixed review fixture, not a tenant-wide enumeration endpoint.
          </p>
        </section>

        <section className="c-panel" aria-labelledby="selected-unit-title">
          <div className="c-panel__header">
            <div>
              <p className="c-panel__eyebrow">Selected exact unit</p>
              <h2 className="c-panel__title" id="selected-unit-title">
                {viewData.selectedUnit.name}
              </h2>
            </div>
            <span className="c-status c-status--positive">Current</span>
          </div>
          <dl className="c-fact-list">
            <div>
              <dt>Classification</dt>
              <dd>{classificationLabels[viewData.selectedUnit.classification]}</dd>
            </div>
            <div>
              <dt>Local label</dt>
              <dd>{viewData.selectedUnit.localLabel}</dd>
            </div>
            <div>
              <dt>Code</dt>
              <dd>{viewData.selectedUnit.code}</dd>
            </div>
            <div>
              <dt>Stable synthetic ID</dt>
              <dd>{viewData.selectedUnit.id}</dd>
            </div>
            <div>
              <dt>Current parent</dt>
              <dd>{viewData.selectedUnit.currentParent}</dd>
            </div>
            <div>
              <dt>Associated site</dt>
              <dd>{viewData.selectedUnit.site}</dd>
            </div>
            <div>
              <dt>Default time zone</dt>
              <dd>{viewData.selectedUnit.timeZone}</dd>
            </div>
          </dl>
        </section>
      </div>

      <div className="l-structure-grid l-structure-grid--balanced">
        <section className="c-panel" aria-labelledby="sites-title">
          <div className="c-panel__header">
            <div>
              <p className="c-panel__eyebrow">Separate identities</p>
              <h2 className="c-panel__title" id="sites-title">
                Sites
              </h2>
            </div>
          </div>
          <ul className="c-relationship-list">
            {viewData.sites.map((site) => (
              <li key={site.label}>
                <strong>{site.label}</strong>
                <span>{site.detail}</span>
              </li>
            ))}
          </ul>
        </section>

        <section className="c-panel" aria-labelledby="affiliations-title">
          <div className="c-panel__header">
            <div>
              <p className="c-panel__eyebrow">Cross-cutting relationship</p>
              <h2 className="c-panel__title" id="affiliations-title">
                Affiliations
              </h2>
            </div>
          </div>
          <ul className="c-relationship-list">
            {viewData.affiliations.map((affiliation) => (
              <li key={affiliation.label}>
                <strong>{affiliation.label}</strong>
                <span>{affiliation.detail}</span>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <section className="c-panel" aria-labelledby="move-preview-title">
        <div className="c-panel__header">
          <div>
            <p className="c-panel__eyebrow">Governed preview · no mutation</p>
            <h2 className="c-panel__title" id="move-preview-title">
              Move impact
            </h2>
          </div>
          <span className="c-status c-status--attention">Blocked</span>
        </div>
        <div className="c-move-summary">
          <strong>{viewData.movePreview.unit}</strong>
          <span>Current parent: {viewData.movePreview.from}</span>
          <span>Proposed parent: {viewData.movePreview.to}</span>
        </div>
        <ul className="c-impact-list">
          {viewData.movePreview.impacts.map((impact) => (
            <li key={impact.meaning}>
              <div>
                <strong>{impact.meaning}</strong>
                <span>{impact.detail}</span>
              </div>
              <span
                className={`c-impact-outcome is-${impact.outcome.replaceAll("_", "-")}`}
              >
                {impactLabels[impact.outcome]}
              </span>
            </li>
          ))}
        </ul>
        <p className="c-panel__footnote">
          The preview deliberately blocks the move because one downstream effect is
          unclassified. No action control is exposed in this L0 prototype.
        </p>
      </section>
    </div>
  );
}
