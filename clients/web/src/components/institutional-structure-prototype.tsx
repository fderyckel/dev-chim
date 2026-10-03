import type {
  InstitutionalStructureViewData,
  InstitutionalUnitNode,
  MoveImpact,
  ReviewStructureNode,
} from "../ports/view-data";
import { PageHeading } from "../design-system/components/page-heading";
import { Panel } from "../design-system/components/panel";
import { StatusBadge } from "../design-system/components/status-badge";

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
              <StatusBadge tone={unit.status === "closed" ? "attention" : "neutral"}>
                {unit.status === "closed" ? "Closed" : "Current"}
              </StatusBadge>
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
              <StatusBadge tone={node.status === "closed" ? "attention" : "neutral"}>
                {node.status === "closed" ? "Closed" : "Current"}
              </StatusBadge>
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
      <PageHeading
        eyebrow="ADR 0025 · L0 review prototype"
        title="Institutional structure"
        description="Review linked legal, corporate, and educational structures without merging their identities or treating any relationship as authority."
        aside={
          <>
            <StatusBadge tone="information">Read-only synthetic evidence</StatusBadge>
            <span className="c-page-heading__assurance-copy">
              No record, access grant, module, report, or placement can change here.
            </span>
          </>
        }
      />

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
        <Panel
          eyebrow="Legal accountability"
          title="Legal entities"
          titleId="legal-entities-title"
          badge={<StatusBadge>Consolidation context</StatusBadge>}
          footer="Consolidation is not ownership, complete control evidence, or authority. Legal relationships outside this tree remain separate."
        >
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
        </Panel>

        <Panel
          eyebrow="Internal organization"
          title="Corporate units"
          titleId="corporate-units-title"
          badge={<StatusBadge>One exact legal entity</StatusBadge>}
        >
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
        </Panel>
      </div>

      <Panel
        eyebrow="Exact link to educational structure"
        title="Legal responsibility"
        titleId="legal-responsibility-title"
        badge={<StatusBadge tone="positive">One primary operator</StatusBadge>}
        footer="A second legal relationship never becomes a second primary operator. An educational unit resolves accountability through its containing institution."
      >
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
      </Panel>

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
        <Panel
          eyebrow="Future-effective example"
          title="Transfer review path"
          titleId="operator-workflow-title"
          badge={<StatusBadge>No automatic activation</StatusBadge>}
        >
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
                <StatusBadge
                  tone={
                    step.state === "complete"
                      ? "positive"
                      : step.state === "current"
                        ? "attention"
                        : "neutral"
                  }
                >
                  {governanceStateLabels[step.state]}
                </StatusBadge>
              </li>
            ))}
          </ol>
        </Panel>

        <Panel
          eyebrow="Controls and evidence"
          title="Approval paths"
          titleId="operator-control-title"
          badge={<StatusBadge tone="positive">Evidence verified</StatusBadge>}
          footer="The structure keeps classified metadata and a protected reference. It does not copy the legal document into this view, audit, or event payload."
        >
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
        </Panel>
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
        <Panel
          eyebrow="Canonical containment"
          title="Five representative contexts"
          titleId="structure-tree-title"
          badge={<StatusBadge>Bounded view</StatusBadge>}
          footer="Primary/early-years, secondary, combined formal education, college, and university contexts are visible in one fixed fixture. This is not a tenant-wide enumeration endpoint or a required type ladder."
        >
          <div className="c-structure-tree">
            <UnitTree
              units={viewData.roots}
              level={1}
              selectedId={viewData.selectedUnit.id}
            />
          </div>
        </Panel>

        <Panel
          eyebrow="Selected exact unit"
          title={viewData.selectedUnit.name}
          titleId="selected-unit-title"
          badge={<StatusBadge tone="positive">Current</StatusBadge>}
        >
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
        </Panel>
      </div>

      <div className="l-structure-grid l-structure-grid--balanced">
        <Panel eyebrow="Separate identities" title="Sites" titleId="sites-title">
          <ul className="c-relationship-list">
            {viewData.sites.map((site) => (
              <li key={site.label}>
                <strong>{site.label}</strong>
                <span>{site.detail}</span>
              </li>
            ))}
          </ul>
        </Panel>

        <Panel
          eyebrow="Cross-cutting relationship"
          title="Affiliations"
          titleId="affiliations-title"
        >
          <ul className="c-relationship-list">
            {viewData.affiliations.map((affiliation) => (
              <li key={affiliation.label}>
                <strong>{affiliation.label}</strong>
                <span>{affiliation.detail}</span>
              </li>
            ))}
          </ul>
        </Panel>
      </div>

      <Panel
        eyebrow="Governed preview · no mutation"
        title="Move impact"
        titleId="move-preview-title"
        tone="attention"
        badge={<StatusBadge tone="attention">Blocked</StatusBadge>}
        footer="The preview deliberately blocks the move because one downstream effect is unclassified. No action control is exposed in this L0 prototype."
      >
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
      </Panel>

      {viewData.linkedStructure.operatorTransferPreviews.map((preview) => {
        const blocked = preview.state === "blocked";

        return (
          <Panel
            eyebrow="Governed preview · no mutation"
            title={`Primary-operator transfer · ${blocked ? "blocked" : "ready"}`}
            titleId={`${preview.id}-title`}
            tone={blocked ? "attention" : "neutral"}
            badge={
              <StatusBadge tone={blocked ? "attention" : "positive"}>
                {blocked ? "Blocked" : "Ready for boundary check"}
              </StatusBadge>
            }
            footer={
              <>
                {blocked
                  ? "An unknown downstream effect blocks this transfer. Historical records remain unchanged."
                  : "All known preconditions are satisfied, but the named activation action must revalidate the facts at the effective boundary."}{" "}
                No action control is exposed in this L0 prototype.
              </>
            }
            key={preview.id}
          >
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
          </Panel>
        );
      })}

      <Panel
        eyebrow="Post-effect evidence invalidation"
        title="Legal accountability under review"
        titleId="accountability-review-title"
        tone="attention"
        badge={<StatusBadge tone="attention">Visible restricted state</StatusBadge>}
        footer="There is no generic dismiss action. This state does not silently verify or replace an operator, close the institution, or change access or module activation."
      >
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
      </Panel>
    </div>
  );
}
