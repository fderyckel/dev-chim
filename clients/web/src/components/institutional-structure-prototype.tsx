import type {
  InstitutionalStructureViewData,
  InstitutionalUnitNode,
  MoveImpact,
  ReviewStructureNode,
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

function ReviewTree({
  nodes,
  level,
  label,
}: Readonly<{
  nodes: ReadonlyArray<ReviewStructureNode>;
  level: number;
  label?: string;
}>) {
  return (
    <ul aria-label={level === 1 ? label : undefined}>
      {nodes.map((node) => {
        const hasChildren = node.children.length > 0;

        return (
          <li className="c-structure-tree__item" key={node.id}>
            <div className="c-structure-tree__row">
              <span className="c-structure-tree__branch" aria-hidden="true">
                {hasChildren ? "−" : "·"}
              </span>
              <span className="c-structure-tree__copy">
                <strong>{node.name}</strong>
                <span>
                  {node.meaning} · {node.reference}
                </span>
              </span>
              <span
                className={
                  node.status === "closed" ? "c-status c-status--attention" : "c-status"
                }
              >
                {node.status === "closed" ? "Closed" : "Current"}
              </span>
            </div>
            {hasChildren ? (
              <ReviewTree nodes={node.children} level={level + 1} />
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
  ready: "Ready",
  blocks_move: "Blocks move",
};

const governanceStateLabels = {
  complete: "Complete",
  current: "Current check",
  pending: "Pending",
} as const;

const accountabilityOutcomeLabels = {
  continues: "Continues",
  fails_closed: "Unavailable",
} as const;

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
            Review linked legal, corporate, and educational structures without merging
            their identities or treating any relationship as authority.
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

      <section className="c-boundary-banner" aria-label="Structure boundary">
        <span className="c-boundary-banner__label">Separate structures</span>
        <p className="c-boundary-banner__copy">
          The tenant contains distinct legal entities, corporate units, educational
          institutions, educational units, and sites. A relationship or visible ancestor
          never grants access, widens a report, changes finance responsibility,
          activates a module, or selects placement.
        </p>
      </section>

      <section className="c-structure-introduction" aria-labelledby="linked-title">
        <p className="c-panel__eyebrow">Linked accountability · separate meanings</p>
        <h2 id="linked-title">Who operates an institution is explicit</h2>
        <p>
          Legal consolidation, ownership or control, corporate containment, and
          educational containment are different relationships. The links below are a
          fixed review context, never a source of implied authority.
        </p>
      </section>

      <div className="l-structure-grid l-structure-grid--balanced">
        <section className="c-panel" aria-labelledby="legal-entities-title">
          <div className="c-panel__header">
            <div>
              <p className="c-panel__eyebrow">Legal accountability</p>
              <h2 className="c-panel__title" id="legal-entities-title">
                Legal entities
              </h2>
            </div>
            <span className="c-status">Consolidation context</span>
          </div>
          <div className="c-structure-tree">
            <ReviewTree
              nodes={viewData.linkedStructure.legalEntities}
              level={1}
              label="Legal consolidation context"
            />
          </div>
          <ul className="c-relationship-list">
            {viewData.linkedStructure.legalRelationships.map((relationship) => (
              <li key={relationship.label}>
                <strong>{relationship.label}</strong>
                <span>{relationship.detail}</span>
              </li>
            ))}
          </ul>
          <p className="c-panel__footnote">
            Consolidation is not ownership, complete control evidence, or authority.
            Legal relationships outside this tree remain separate.
          </p>
        </section>

        <section className="c-panel" aria-labelledby="corporate-units-title">
          <div className="c-panel__header">
            <div>
              <p className="c-panel__eyebrow">Internal organization</p>
              <h2 className="c-panel__title" id="corporate-units-title">
                Corporate units
              </h2>
            </div>
            <span className="c-status">One exact legal entity</span>
          </div>
          <div className="c-structure-tree">
            <ReviewTree
              nodes={viewData.linkedStructure.corporateUnits}
              level={1}
              label="Corporate containment"
            />
          </div>
          <dl className="c-fact-list">
            <div>
              <dt>Belongs to legal entity</dt>
              <dd>{viewData.linkedStructure.corporateOwner}</dd>
            </div>
            <div>
              <dt>Does not imply</dt>
              <dd>Finance access, employment, workflow, or programme ownership</dd>
            </div>
          </dl>
        </section>
      </div>

      <section className="c-panel" aria-labelledby="legal-responsibility-title">
        <div className="c-panel__header">
          <div>
            <p className="c-panel__eyebrow">Exact link to educational structure</p>
            <h2 className="c-panel__title" id="legal-responsibility-title">
              Legal responsibility
            </h2>
          </div>
          <span className="c-status c-status--positive">One primary operator</span>
        </div>
        <dl className="c-fact-list">
          <div>
            <dt>Educational institution</dt>
            <dd>{viewData.linkedStructure.responsibility.institution}</dd>
          </div>
          <div>
            <dt>Primary legal operator</dt>
            <dd>{viewData.linkedStructure.responsibility.primaryOperator}</dd>
          </div>
        </dl>
        <ul className="c-relationship-list">
          {viewData.linkedStructure.responsibility.otherRelationships.map(
            (relationship) => (
              <li key={relationship.label}>
                <strong>{relationship.label}</strong>
                <span>{relationship.detail}</span>
              </li>
            ),
          )}
        </ul>
        <p className="c-panel__footnote">
          A second legal relationship never becomes a second primary operator. An
          educational unit resolves accountability through its containing institution.
        </p>
      </section>

      <section className="c-structure-introduction" aria-labelledby="governance-title">
        <p className="c-panel__eyebrow">Primary-operator governance</p>
        <h2 id="governance-title">
          A transfer is reviewed before it becomes effective
        </h2>
        <p>
          Proposal, evidence verification, approval, effective-boundary revalidation,
          and activation are distinct facts. A future date never activates a transfer by
          itself.
        </p>
      </section>

      <div className="l-structure-grid l-structure-grid--balanced">
        <section className="c-panel" aria-labelledby="operator-workflow-title">
          <div className="c-panel__header">
            <div>
              <p className="c-panel__eyebrow">Future-effective example</p>
              <h2 className="c-panel__title" id="operator-workflow-title">
                Transfer review path
              </h2>
            </div>
            <span className="c-status">No automatic activation</span>
          </div>
          <ol className="c-governance-steps">
            {viewData.linkedStructure.operatorGovernance.workflow.map((step, index) => (
              <li key={step.label}>
                <span className="c-governance-steps__number" aria-hidden="true">
                  {index + 1}
                </span>
                <div>
                  <strong>{step.label}</strong>
                  <span className="c-governance-steps__detail">{step.detail}</span>
                </div>
                <span
                  className={`c-status c-governance-steps__state c-status--governance-${step.state}`}
                >
                  {governanceStateLabels[step.state]}
                </span>
              </li>
            ))}
          </ol>
        </section>

        <section className="c-panel" aria-labelledby="operator-control-title">
          <div className="c-panel__header">
            <div>
              <p className="c-panel__eyebrow">Controls and evidence</p>
              <h2 className="c-panel__title" id="operator-control-title">
                Approval paths
              </h2>
            </div>
            <span className="c-status c-status--positive">Evidence verified</span>
          </div>
          <ul className="c-relationship-list">
            {viewData.linkedStructure.operatorGovernance.approvalPaths.map((path) => (
              <li key={path.label}>
                <strong>{path.label}</strong>
                <span>{path.detail}</span>
              </li>
            ))}
          </ul>
          <dl className="c-fact-list c-fact-list--separated">
            <div>
              <dt>Evidence type</dt>
              <dd>{viewData.linkedStructure.operatorGovernance.evidence.type}</dd>
            </div>
            <div>
              <dt>Protected source</dt>
              <dd>{viewData.linkedStructure.operatorGovernance.evidence.source}</dd>
            </div>
            <div>
              <dt>Reference</dt>
              <dd>{viewData.linkedStructure.operatorGovernance.evidence.reference}</dd>
            </div>
            <div>
              <dt>Classification</dt>
              <dd>
                {viewData.linkedStructure.operatorGovernance.evidence.classification}
              </dd>
            </div>
            <div>
              <dt>Verified</dt>
              <dd>{viewData.linkedStructure.operatorGovernance.evidence.verifiedOn}</dd>
            </div>
          </dl>
          <p className="c-panel__footnote">
            The structure keeps classified metadata and a protected reference. It does
            not copy the legal document into this view, audit, or event payload.
          </p>
        </section>
      </div>

      <section className="c-structure-introduction" aria-labelledby="education-title">
        <p className="c-panel__eyebrow">Educational structure</p>
        <h2 id="education-title">Institutions and educational units</h2>
        <p>
          This separate forest describes educational containment. It does not mirror the
          legal consolidation or corporate-unit trees.
        </p>
      </section>

      <div className="l-structure-grid">
        <section className="c-panel" aria-labelledby="structure-tree-title">
          <div className="c-panel__header">
            <div>
              <p className="c-panel__eyebrow">Canonical containment</p>
              <h2 className="c-panel__title" id="structure-tree-title">
                Five representative contexts
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
            Primary/early-years, secondary, combined formal education, college, and
            university contexts are visible in one fixed fixture. This is not a
            tenant-wide enumeration endpoint or a required type ladder.
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

      {viewData.linkedStructure.operatorTransferPreviews.map((preview) => {
        const blocked = preview.state === "blocked";

        return (
          <section
            className="c-panel"
            aria-labelledby={`${preview.id}-title`}
            key={preview.id}
          >
            <div className="c-panel__header">
              <div>
                <p className="c-panel__eyebrow">Governed preview · no mutation</p>
                <h2 className="c-panel__title" id={`${preview.id}-title`}>
                  Primary-operator transfer · {blocked ? "blocked" : "ready"}
                </h2>
              </div>
              <span
                className={
                  blocked
                    ? "c-status c-status--attention"
                    : "c-status c-status--positive"
                }
              >
                {blocked ? "Blocked" : "Ready for boundary check"}
              </span>
            </div>
            <div className="c-move-summary c-move-summary--operator">
              <strong>{preview.institution}</strong>
              <span>Current operator: {preview.from}</span>
              <span>Proposed operator: {preview.to}</span>
              <span>Intended effective date: {preview.effectiveOn}</span>
            </div>
            <ul className="c-impact-list">
              {preview.impacts.map((impact) => (
                <li key={impact.meaning}>
                  <div>
                    <strong>{impact.meaning}</strong>
                    <span>{impact.detail}</span>
                  </div>
                  <span
                    className={
                      "c-impact-outcome is-" + impact.outcome.replaceAll("_", "-")
                    }
                  >
                    {impact.outcome === "blocks_move"
                      ? "Blocks transfer"
                      : impactLabels[impact.outcome]}
                  </span>
                </li>
              ))}
            </ul>
            <p className="c-panel__footnote">
              {blocked
                ? "An unknown downstream effect blocks this transfer. Historical records remain unchanged."
                : "All known preconditions are satisfied, but the named activation action must revalidate the facts at the effective boundary."}{" "}
              No action control is exposed in this L0 prototype.
            </p>
          </section>
        );
      })}

      <section className="c-panel" aria-labelledby="accountability-review-title">
        <div className="c-panel__header">
          <div>
            <p className="c-panel__eyebrow">Post-effect evidence invalidation</p>
            <h2 className="c-panel__title" id="accountability-review-title">
              Legal accountability under review
            </h2>
          </div>
          <span className="c-status c-status--attention">Visible restricted state</span>
        </div>
        <div className="c-review-summary">
          <strong>
            {
              viewData.linkedStructure.operatorGovernance.accountabilityReview
                .institution
            }
          </strong>
          <span className="c-review-summary__status">
            {viewData.linkedStructure.operatorGovernance.accountabilityReview.status}
          </span>
          <p className="c-review-summary__trigger">
            {viewData.linkedStructure.operatorGovernance.accountabilityReview.trigger}
          </p>
        </div>
        <ul className="c-impact-list">
          {viewData.linkedStructure.operatorGovernance.accountabilityReview.actions.map(
            (action) => (
              <li key={action.label}>
                <div>
                  <strong>{action.label}</strong>
                  <span>{action.detail}</span>
                </div>
                <span
                  className={`c-impact-outcome is-${action.outcome.replaceAll("_", "-")}`}
                >
                  {accountabilityOutcomeLabels[action.outcome]}
                </span>
              </li>
            ),
          )}
        </ul>
        <div className="c-resolution-paths">
          <strong>Named resolution paths</strong>
          <ul className="c-resolution-paths__list">
            {viewData.linkedStructure.operatorGovernance.accountabilityReview.resolutionPaths.map(
              (path) => (
                <li key={path}>{path}</li>
              ),
            )}
          </ul>
        </div>
        <p className="c-panel__footnote">
          There is no generic dismiss action. This state does not silently verify or
          replace an operator, close the institution, or change access or module
          activation.
        </p>
      </section>
    </div>
  );
}
