import type { AssignmentOptionsData } from "../ports/core-bridge";
import { ActionButton } from "../design-system/components/actions";
import { PageHeading } from "../design-system/components/page-heading";
import { StatusBadge } from "../design-system/components/status-badge";

type AssignmentPreparationProps = Readonly<{
  data: AssignmentOptionsData;
}>;

export function AssignmentPreparation({ data }: AssignmentPreparationProps) {
  return (
    <div className="l-page-stack">
      <PageHeading
        eyebrow="Authority preparation"
        title="Prepare a role assignment"
        description="Review tenant-qualified membership and role options read from the local core. This slice cannot save or change an assignment."
        aside={
          <>
            <StatusBadge tone="positive">Core read ready</StatusBadge>
            <span className="c-page-heading__assurance-copy">
              Contract v{data.contract_version} · local only
            </span>
          </>
        }
      />

      <aside className="c-read-boundary" aria-label="Read-only boundary">
        <span className="c-read-boundary__mark" aria-hidden="true">
          i
        </span>
        <div className="c-read-boundary__body">
          <strong className="c-read-boundary__title">Preparation only</strong>
          <p className="c-read-boundary__copy">
            The choices below came through server-side authorization. The browser
            receives no tenant, actor, routing, repository, or capability identifiers.
          </p>
        </div>
      </aside>

      <section className="c-assignment-card" aria-labelledby="assignment-form-title">
        <div className="c-assignment-card__header">
          <div>
            <p className="c-panel__eyebrow">Read-only task preview</p>
            <h2 className="c-assignment-card__title" id="assignment-form-title">
              Select the intended assignment
            </h2>
          </div>
          <StatusBadge>
            {data.memberships.length + data.roles.length} options
          </StatusBadge>
        </div>

        <form className="c-assignment-form">
          <div className="l-assignment-fields">
            <label className="c-field" htmlFor="membership-option">
              <span className="c-field__label">Membership</span>
              <select
                className="c-input c-input--select"
                defaultValue=""
                id="membership-option"
                name="membership"
              >
                <option disabled value="">
                  Choose a synthetic membership
                </option>
                {data.memberships.map((membership) => (
                  <option key={membership.id} value={membership.id}>
                    {membership.label}
                  </option>
                ))}
              </select>
              <span className="c-field__hint">
                Labels are browser-safe local references, not actor identities.
              </span>
            </label>

            <label className="c-field" htmlFor="role-option">
              <span className="c-field__label">Tenant-defined role</span>
              <select
                className="c-input c-input--select"
                defaultValue=""
                id="role-option"
                name="role"
              >
                <option disabled value="">
                  Choose a role
                </option>
                {data.roles.map((role) => (
                  <option key={role.id} value={role.id}>
                    {role.label}
                  </option>
                ))}
              </select>
              <span className="c-field__hint">
                Roles are tenant data; they are not fixed production job titles.
              </span>
            </label>
          </div>

          <div className="c-assignment-form__actions">
            <ActionButton disabled variant="primary">
              Save unavailable in UI-1A
            </ActionButton>
            <p className="c-assignment-form__note">
              No write request, mutation route, or browser persistence exists in this
              slice.
            </p>
          </div>
        </form>
      </section>
    </div>
  );
}
