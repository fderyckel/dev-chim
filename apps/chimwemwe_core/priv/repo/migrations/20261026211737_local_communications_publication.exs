defmodule Chimwemwe.Repo.Migrations.LocalCommunicationsPublication do
  @moduledoc "Generated Ash expansion, reordered after review: all tenant indexes precede compound/circular foreign keys; retained evidence refuses rollback."
  use Ecto.Migration

  def up do
    execute("SET LOCAL lock_timeout = '2s'")

    create(table(:communications_notices, primary_key: false)) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:institution_id, :uuid, null: false)
      add(:author_id, :uuid, null: false)
      add(:title, :text, null: false)
      add(:body, :text, null: false)
      add(:receipt_required, :boolean, null: false)
      add(:state, :text, null: false)
      add(:lock_version, :bigint, null: false)
      add(:current_revision_number, :bigint, null: false)
      add(:submitted_preparation_id, :uuid)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create(table(:communications_preparations, primary_key: false)) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:notice_id, :uuid, null: false)
      add(:proposer_id, :uuid, null: false)
      add(:proposer_membership_id, :uuid, null: false)
      add(:base_version, :bigint, null: false)
      add(:operation, :text, null: false)
      add(:title, :text, null: false)
      add(:body, :text, null: false)
      add(:reason, :text, null: false)
      add(:receipt_required, :boolean, null: false)
      add(:expected_revision_number, :bigint, null: false)
      add(:source_proof, :binary, null: false)
      add(:eligibility, :map, null: false)
      add(:expires_at, :utc_datetime_usec, null: false)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create(table(:communications_revisions, primary_key: false)) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:notice_id, :uuid, null: false)
      add(:preparation_id, :uuid, null: false)
      add(:number, :bigint, null: false)
      add(:proposer_id, :uuid, null: false)
      add(:approver_id, :uuid, null: false)
      add(:title, :text, null: false)
      add(:body, :text, null: false)
      add(:reason, :text, null: false)
      add(:receipt_required, :boolean, null: false)
      add(:original_proof, :binary, null: false)
      add(:eligibility, :map, null: false)
      add(:published_at, :utc_datetime_usec, null: false)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create(table(:communications_engagements, primary_key: false)) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:tenant_id, :uuid, null: false)
      add(:notice_id, :uuid, null: false)
      add(:revision_id, :uuid, null: false)
      add(:person_id, :uuid, null: false)
      add(:actor_id, :uuid, null: false)
      add(:kind, :text, null: false)
      add(:statement, :text)
      add(:recorded_at, :utc_datetime_usec, null: false)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create(
      index(:communications_preparations, [:id, :tenant_id],
        name: "communications_preparations_id_tenant_idx",
        unique: true
      )
    )

    create(
      index(:communications_revisions, [:id, :tenant_id],
        name: "communications_revisions_id_tenant_idx",
        unique: true
      )
    )

    create(
      index(:communications_revisions, [:tenant_id, :notice_id, :number],
        name: "communications_revisions_unique_0",
        unique: true
      )
    )

    create(
      index(:communications_engagements, [:id, :tenant_id],
        name: "communications_engagements_id_tenant_idx",
        unique: true
      )
    )

    create(
      index(:communications_engagements, [:tenant_id, :revision_id, :person_id, :kind],
        name: "communications_engagements_unique_0",
        unique: true
      )
    )

    create(
      index(:communications_notices, [:id, :tenant_id],
        name: "communications_notices_id_tenant_idx",
        unique: true
      )
    )

    execute(
      "ALTER TABLE communications_notices ADD CONSTRAINT communications_notices_institution_id_fkey FOREIGN KEY (institution_id,tenant_id) REFERENCES institutional_units(id,tenant_id) MATCH FULL ON DELETE RESTRICT NOT VALID"
    )

    execute(
      "ALTER TABLE communications_notices VALIDATE CONSTRAINT communications_notices_institution_id_fkey"
    )

    execute(
      "ALTER TABLE communications_notices ADD CONSTRAINT communications_notices_submitted_preparation_id_fkey FOREIGN KEY (submitted_preparation_id,tenant_id) REFERENCES communications_preparations(id,tenant_id) MATCH SIMPLE ON DELETE RESTRICT NOT VALID"
    )

    execute(
      "ALTER TABLE communications_notices VALIDATE CONSTRAINT communications_notices_submitted_preparation_id_fkey"
    )

    execute(
      "ALTER TABLE communications_revisions ADD CONSTRAINT communications_revisions_preparation_id_fkey FOREIGN KEY (preparation_id,tenant_id) REFERENCES communications_preparations(id,tenant_id) MATCH FULL ON DELETE RESTRICT NOT VALID"
    )

    execute(
      "ALTER TABLE communications_revisions VALIDATE CONSTRAINT communications_revisions_preparation_id_fkey"
    )

    execute(
      "ALTER TABLE communications_engagements ADD CONSTRAINT communications_engagements_revision_id_fkey FOREIGN KEY (revision_id,tenant_id) REFERENCES communications_revisions(id,tenant_id) MATCH FULL ON DELETE RESTRICT NOT VALID"
    )

    execute(
      "ALTER TABLE communications_engagements VALIDATE CONSTRAINT communications_engagements_revision_id_fkey"
    )

    execute(
      "ALTER TABLE communications_engagements ADD CONSTRAINT communications_engagements_person_id_fkey FOREIGN KEY (person_id,tenant_id) REFERENCES people_persons(id,tenant_id) MATCH FULL ON DELETE RESTRICT NOT VALID"
    )

    execute(
      "ALTER TABLE communications_engagements VALIDATE CONSTRAINT communications_engagements_person_id_fkey"
    )

    execute(
      "ALTER TABLE communications_preparations ADD CONSTRAINT communications_preparations_notice_id_fkey FOREIGN KEY (notice_id,tenant_id) REFERENCES communications_notices(id,tenant_id) MATCH FULL ON DELETE RESTRICT NOT VALID"
    )

    execute(
      "ALTER TABLE communications_preparations VALIDATE CONSTRAINT communications_preparations_notice_id_fkey"
    )

    execute(
      "ALTER TABLE communications_revisions ADD CONSTRAINT communications_revisions_notice_id_fkey FOREIGN KEY (notice_id,tenant_id) REFERENCES communications_notices(id,tenant_id) MATCH FULL ON DELETE RESTRICT NOT VALID"
    )

    execute(
      "ALTER TABLE communications_revisions VALIDATE CONSTRAINT communications_revisions_notice_id_fkey"
    )

    execute(
      "ALTER TABLE communications_engagements ADD CONSTRAINT communications_engagements_notice_id_fkey FOREIGN KEY (notice_id,tenant_id) REFERENCES communications_notices(id,tenant_id) MATCH FULL ON DELETE RESTRICT NOT VALID"
    )

    execute(
      "ALTER TABLE communications_engagements VALIDATE CONSTRAINT communications_engagements_notice_id_fkey"
    )

    drop_if_exists(
      constraint(:platform_outbox_events, :platform_outbox_classification_domain_boundary)
    )

    create(
      constraint(:platform_outbox_events, :platform_outbox_classification_domain_boundary,
        check:
          "  (classification = 'internal' AND aggregate_type <> 'identity.staff_accounts.entry' AND aggregate_type NOT LIKE 'communications.core.%' AND aggregate_type NOT LIKE 'people.core.%' AND aggregate_type NOT LIKE 'classroom.core.%' AND aggregate_type NOT LIKE 'classroom.attendance.%') OR (classification = 'restricted' AND aggregate_type IN ('people.core.person', 'people.core.participation', 'people.core.account') AND event_type LIKE 'people.core.%') OR (classification = 'restricted' AND aggregate_type IN ('classroom.core.class', 'classroom.core.enrolment', 'classroom.core.assignment', 'classroom.core.placement') AND event_type LIKE 'classroom.core.%') OR (classification = 'restricted' AND aggregate_type = 'classroom.attendance.submission' AND event_type IN ('classroom.attendance.submit.completed', 'classroom.attendance.correct.completed')) OR (classification = 'restricted' AND aggregate_type = 'identity.staff_accounts.entry' AND event_type IN ('identity.staff_accounts.provision.completed', 'identity.staff_accounts.revise_details.completed', 'identity.staff_accounts.set_access.completed', 'identity.staff_accounts.revoke_access_profile.completed', 'identity.staff_accounts.suspend_access.completed', 'identity.staff_accounts.reissue.completed', 'identity.staff_accounts.set_preferences.completed')) OR (classification = 'restricted' AND aggregate_type = 'communications.core.notice' AND event_type IN ('communications.core.create_draft.completed','communications.core.revise_draft.completed','communications.core.prepare_operation.completed','communications.core.submit_for_approval.completed','communications.core.approve_operation.completed','communications.core.open_notice.completed','communications.core.confirm_receipt.completed'))\n"
      )
    )

    create(
      constraint(:communications_preparations, :communications_preparation_operation,
        check: "  operation IN ('publish','correct','withdraw')\n"
      )
    )

    create(
      constraint(:communications_preparations, :communications_preparation_versions,
        check: "  base_version > 0 AND expected_revision_number BETWEEN 0 AND 2\n"
      )
    )

    create(
      constraint(:communications_preparations, :communications_preparation_text,
        check:
          "  char_length(title) BETWEEN 1 AND 120 AND char_length(body) BETWEEN 1 AND 2000 AND char_length(reason) <= 240\n"
      )
    )

    create(
      constraint(:communications_revisions, :communications_revision_number,
        check: "  number BETWEEN 1 AND 2\n"
      )
    )

    create(
      constraint(:communications_revisions, :communications_independent_approval,
        check: "  approver_id <> proposer_id\n"
      )
    )

    create(
      constraint(:communications_revisions, :communications_revision_text,
        check:
          "  char_length(title) BETWEEN 1 AND 120 AND char_length(body) BETWEEN 1 AND 2000 AND char_length(reason) <= 240\n"
      )
    )

    create(
      constraint(:communications_engagements, :communications_engagement_kind,
        check:
          "  (kind = 'opening' AND statement IS NULL) OR (kind = 'receipt' AND statement = 'I acknowledge receipt of this notice.')\n"
      )
    )

    create(
      constraint(:communications_notices, :communications_notice_state,
        check: "  state IN ('draft','pending','published','withdrawn')\n"
      )
    )

    create(
      constraint(:communications_notices, :communications_notice_versions,
        check: "  lock_version > 0 AND current_revision_number BETWEEN 0 AND 2\n"
      )
    )

    create(
      constraint(:communications_notices, :communications_notice_text,
        check: "  char_length(title) BETWEEN 1 AND 120 AND char_length(body) BETWEEN 1 AND 2000\n"
      )
    )

    execute(
      "DO $migration$ BEGIN\nCREATE FUNCTION communications_preparations_immutable() RETURNS trigger LANGUAGE plpgsql AS $$\nBEGIN RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'communication evidence is retained and immutable'; END $$;\nCREATE TRIGGER communications_preparations_immutable BEFORE UPDATE OR DELETE ON communications_preparations\n  FOR EACH ROW EXECUTE FUNCTION communications_preparations_immutable();\nEND $migration$;\n"
    )

    execute(
      "DO $migration$ BEGIN\nCREATE FUNCTION communications_revisions_immutable() RETURNS trigger LANGUAGE plpgsql AS $$\nBEGIN RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'communication evidence is retained and immutable'; END $$;\nCREATE TRIGGER communications_revisions_immutable BEFORE UPDATE OR DELETE ON communications_revisions\n  FOR EACH ROW EXECUTE FUNCTION communications_revisions_immutable();\nEND $migration$;\n"
    )

    execute(
      "DO $migration$ BEGIN\nCREATE FUNCTION communications_engagements_immutable() RETURNS trigger LANGUAGE plpgsql AS $$\nBEGIN RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'communication evidence is retained and immutable'; END $$;\nCREATE TRIGGER communications_engagements_immutable BEFORE UPDATE OR DELETE ON communications_engagements\n  FOR EACH ROW EXECUTE FUNCTION communications_engagements_immutable();\nEND $migration$;\n"
    )

    execute(
      "DO $migration$ BEGIN\nCREATE FUNCTION communications_notice_guard() RETURNS trigger LANGUAGE plpgsql AS $$\nDECLARE amount integer;\nBEGIN\n  IF TG_OP = 'DELETE' THEN\n    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication state is retained';\n  END IF;\n  IF TG_OP = 'INSERT' THEN\n    PERFORM pg_advisory_xact_lock(hashtextextended('communications-institution:' || NEW.tenant_id::text || ':' || NEW.institution_id::text,0));\n    SELECT count(*) INTO amount FROM communications_notices WHERE tenant_id=NEW.tenant_id AND institution_id=NEW.institution_id;\n    IF amount >= 5 OR NEW.lock_version <> 1 OR NEW.current_revision_number <> 0 OR NEW.state <> 'draft' THEN\n      RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication creation bound';\n    END IF;\n  ELSE\n    IF (NEW.id,NEW.tenant_id,NEW.institution_id,NEW.author_id,NEW.inserted_at)\n        IS DISTINCT FROM (OLD.id,OLD.tenant_id,OLD.institution_id,OLD.author_id,OLD.inserted_at)\n        OR OLD.state='withdrawn' OR NEW.lock_version <> OLD.lock_version+1\n        OR NEW.current_revision_number NOT BETWEEN OLD.current_revision_number AND OLD.current_revision_number+1\n        OR (OLD.current_revision_number>0 AND (NEW.receipt_required,NEW.title,NEW.body) IS DISTINCT FROM (OLD.receipt_required,OLD.title,OLD.body)) THEN\n      RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication transition rejected';\n    END IF;\n  END IF;\n  IF NEW.submitted_preparation_id IS NOT NULL AND NOT EXISTS\n    (SELECT 1 FROM communications_preparations p WHERE p.tenant_id=NEW.tenant_id AND p.id=NEW.submitted_preparation_id AND p.notice_id=NEW.id) THEN\n    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication preparation scope rejected';\n  END IF;\n  RETURN NEW;\nEND $$;\nCREATE TRIGGER communications_notice_guard BEFORE INSERT OR UPDATE OR DELETE ON communications_notices\n  FOR EACH ROW EXECUTE FUNCTION communications_notice_guard();\nCREATE FUNCTION communications_revision_guard() RETURNS trigger LANGUAGE plpgsql AS $$\nBEGIN\n  IF NOT EXISTS (\n    SELECT 1 FROM communications_notices n JOIN communications_preparations p\n      ON p.tenant_id=n.tenant_id AND p.notice_id=n.id\n    WHERE n.tenant_id=NEW.tenant_id AND n.id=NEW.notice_id AND p.id=NEW.preparation_id\n      AND n.state='pending' AND n.submitted_preparation_id=p.id AND n.lock_version=p.base_version+1\n      AND n.current_revision_number+1=NEW.number AND n.receipt_required=NEW.receipt_required\n      AND (p.proposer_id,p.title,p.body,p.reason,p.receipt_required)\n        IS NOT DISTINCT FROM (NEW.proposer_id,NEW.title,NEW.body,NEW.reason,NEW.receipt_required)\n      AND p.operation IN ('publish','correct')\n  ) OR (NEW.eligibility->>'audience')::int NOT BETWEEN 1 AND 25\n     OR (NEW.eligibility->>'eligible')::int < 0\n     OR (NEW.eligibility->>'no_eligible_account')::int < 0\n     OR (NEW.eligibility->>'no_current_access')::int < 0\n     OR (NEW.eligibility->>'audience')::int <>\n       (NEW.eligibility->>'eligible')::int+(NEW.eligibility->>'no_eligible_account')::int+(NEW.eligibility->>'no_current_access')::int THEN\n    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication revision scope rejected';\n  END IF;\n  RETURN NEW;\nEND $$;\nCREATE TRIGGER communications_revision_guard BEFORE INSERT ON communications_revisions\n  FOR EACH ROW EXECUTE FUNCTION communications_revision_guard();\nCREATE FUNCTION communications_engagement_guard() RETURNS trigger LANGUAGE plpgsql AS $$\nBEGIN\n  IF NOT EXISTS (SELECT 1 FROM communications_revisions r JOIN communications_notices n\n    ON n.tenant_id=r.tenant_id AND n.id=r.notice_id WHERE r.tenant_id=NEW.tenant_id\n    AND r.id=NEW.revision_id AND r.notice_id=NEW.notice_id\n    AND r.number=n.current_revision_number AND n.state <> 'withdrawn'\n    AND (NEW.kind='opening' OR r.receipt_required)) THEN\n    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication engagement scope rejected';\n  END IF;\n  RETURN NEW;\nEND $$;\nCREATE TRIGGER communications_engagement_guard BEFORE INSERT ON communications_engagements\n  FOR EACH ROW EXECUTE FUNCTION communications_engagement_guard();\nEND $migration$;\n"
    )
  end

  def down do
    execute("SET LOCAL lock_timeout = '2s'")

    execute(
      "DO $migration$ BEGIN\nIF EXISTS (SELECT 1 FROM communications_notices) OR EXISTS (SELECT 1 FROM communications_preparations)\n OR EXISTS (SELECT 1 FROM communications_revisions) OR EXISTS (SELECT 1 FROM communications_engagements)\n OR EXISTS (SELECT 1 FROM platform_authority_audit_events WHERE action_name LIKE 'communications.core.%')\n OR EXISTS (SELECT 1 FROM platform_outbox_events WHERE aggregate_type LIKE 'communications.core.%')\n OR EXISTS (SELECT 1 FROM platform_authority_action_idempotency WHERE action_name LIKE 'communications.core.%') THEN\n RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='retained communications require forward repair';\nEND IF;\nEND $migration$;\n"
    )

    execute(
      "DO $migration$ BEGIN\nDROP TRIGGER communications_engagement_guard ON communications_engagements;\nDROP FUNCTION communications_engagement_guard();\nDROP TRIGGER communications_revision_guard ON communications_revisions;\nDROP FUNCTION communications_revision_guard();\nDROP TRIGGER communications_notice_guard ON communications_notices;\nDROP FUNCTION communications_notice_guard();\nEND $migration$;\n"
    )

    execute(
      "DO $migration$ BEGIN DROP TRIGGER communications_engagements_immutable ON communications_engagements; DROP FUNCTION communications_engagements_immutable(); END $migration$;\n"
    )

    execute(
      "DO $migration$ BEGIN DROP TRIGGER communications_revisions_immutable ON communications_revisions; DROP FUNCTION communications_revisions_immutable(); END $migration$;\n"
    )

    execute(
      "DO $migration$ BEGIN DROP TRIGGER communications_preparations_immutable ON communications_preparations; DROP FUNCTION communications_preparations_immutable(); END $migration$;\n"
    )

    execute(
      "ALTER TABLE communications_engagements DROP CONSTRAINT communications_engagements_person_id_fkey"
    )

    execute(
      "ALTER TABLE communications_engagements DROP CONSTRAINT communications_engagements_revision_id_fkey"
    )

    execute(
      "ALTER TABLE communications_revisions DROP CONSTRAINT communications_revisions_preparation_id_fkey"
    )

    execute(
      "ALTER TABLE communications_notices DROP CONSTRAINT communications_notices_submitted_preparation_id_fkey"
    )

    execute(
      "ALTER TABLE communications_notices DROP CONSTRAINT communications_notices_institution_id_fkey"
    )

    execute(
      "ALTER TABLE communications_preparations DROP CONSTRAINT communications_preparations_notice_id_fkey"
    )

    execute(
      "ALTER TABLE communications_revisions DROP CONSTRAINT communications_revisions_notice_id_fkey"
    )

    execute(
      "ALTER TABLE communications_engagements DROP CONSTRAINT communications_engagements_notice_id_fkey"
    )

    drop(table(:communications_engagements))
    drop(table(:communications_revisions))
    drop(table(:communications_preparations))
    drop(table(:communications_notices))
    drop(constraint(:platform_outbox_events, :platform_outbox_classification_domain_boundary))

    create(
      constraint(:platform_outbox_events, :platform_outbox_classification_domain_boundary,
        check:
          "  (classification = 'internal' AND aggregate_type <> 'identity.staff_accounts.entry' AND aggregate_type NOT LIKE 'people.core.%' AND aggregate_type NOT LIKE 'classroom.core.%' AND aggregate_type NOT LIKE 'classroom.attendance.%') OR (classification = 'restricted' AND aggregate_type IN ('people.core.person', 'people.core.participation', 'people.core.account') AND event_type LIKE 'people.core.%') OR (classification = 'restricted' AND aggregate_type IN ('classroom.core.class', 'classroom.core.enrolment', 'classroom.core.assignment', 'classroom.core.placement') AND event_type LIKE 'classroom.core.%') OR (classification = 'restricted' AND aggregate_type = 'classroom.attendance.submission' AND event_type IN ('classroom.attendance.submit.completed', 'classroom.attendance.correct.completed')) OR (classification = 'restricted' AND aggregate_type = 'identity.staff_accounts.entry' AND event_type IN ('identity.staff_accounts.provision.completed', 'identity.staff_accounts.revise_details.completed', 'identity.staff_accounts.set_access.completed', 'identity.staff_accounts.revoke_access_profile.completed', 'identity.staff_accounts.suspend_access.completed', 'identity.staff_accounts.reissue.completed', 'identity.staff_accounts.set_preferences.completed'))\n"
      )
    )
  end
end
