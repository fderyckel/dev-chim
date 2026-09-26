from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path


def load_checker():
    root = Path(__file__).resolve().parents[2]
    module_path = root / "tools/check_phase0.py"
    spec = importlib.util.spec_from_file_location("check_phase0", module_path)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = load_checker()
ROOT = Path(__file__).resolve().parents[2]


def test_current_repository_contract_passes() -> None:
    assert CHECKER.validate_repository(ROOT) == []


def test_generated_browser_reports_are_outside_documentation_validation() -> None:
    assert {"playwright-report", "test-results"} <= CHECKER.IGNORED_DIRECTORY_NAMES


def test_broken_relative_link_is_reported(tmp_path: Path) -> None:
    document = tmp_path / "document.md"
    document.write_text("# Document\n\n[Missing](missing.md)\n", encoding="utf-8")

    assert CHECKER.markdown_errors(document, tmp_path) == [
        "document.md: broken relative link 'missing.md'"
    ]


def test_exit_review_accepts_completed_phase_zero_state() -> None:
    assert CHECKER.exit_review_errors(ROOT) == []


def test_exit_review_and_repository_contract_pass_together() -> None:
    assert CHECKER.validate_repository(ROOT, exit_review=True) == []


def test_phase_zero_exit_scope_comes_from_decision_register(tmp_path: Path) -> None:
    decision_register = tmp_path / "docs/phase-0/decision-register.md"
    decision_register.parent.mkdir(parents=True)
    decision_register.write_text(
        "| [0001](../adr/0001-in-scope.md) | Accepted |\n"
        "| [0002](../adr/0002-also-in-scope.md) | Deferred |\n",
        encoding="utf-8",
    )

    matches = CHECKER.PHASE0_DECISION_ADR_PATTERN.findall(
        decision_register.read_text(encoding="utf-8")
    )

    assert matches == [
        ("0001", "0001-in-scope.md"),
        ("0002", "0002-also-in-scope.md"),
    ]


def test_nonpatch_upgrade_evidence_preserves_the_historical_comparison() -> None:
    assert CHECKER.ash_upgrade_evidence_errors(ROOT) == []


def test_nonpatch_upgrade_evidence_rejects_undispositioned_warning_delta() -> None:
    path = ROOT / "spikes/ash-foundation-lab/priv/maintenance/ash-nonpatch-upgrade.json"
    evidence = copy.deepcopy(json.loads(path.read_text(encoding="utf-8")))
    evidence["warnings"]["removed"] = 0

    assert CHECKER.ash_upgrade_document_errors(evidence, ROOT) == [
        "ash non-patch upgrade evidence: warning delta is not fully dispositioned"
    ]


def test_retained_data_measurement_matches_current_sources_and_safety_contract() -> None:
    assert CHECKER.retained_data_measurement_evidence_errors(ROOT) == []


def test_retained_data_measurement_rejects_a_failed_tenant_assertion() -> None:
    path = (
        ROOT / "spikes/ash-foundation-lab/priv/maintenance/retained-data-migration-measurement.json"
    )
    evidence = copy.deepcopy(json.loads(path.read_text(encoding="utf-8")))
    evidence["runs"][0]["assertions"]["control_tenant_untouched_during_primary_backfill"] = False

    assert CHECKER.retained_data_measurement_document_errors(evidence, ROOT) == [
        "retained-data migration measurement: repetition 1 has a failed or missing safety assertion"
    ]


def test_ash_bounded_conditions_match_the_owned_boundary_manifest() -> None:
    assert CHECKER.ash_bounded_condition_disposition_errors(ROOT) == []


def test_ash_bounded_conditions_reject_a_weakened_accountable_decision() -> None:
    disposition_path = (
        ROOT / "spikes/ash-foundation-lab/priv/maintenance/ash-bounded-condition-disposition.json"
    )
    manifest_path = ROOT / "spikes/ash-foundation-lab/priv/maintenance/owned-boundaries.json"
    disposition = copy.deepcopy(json.loads(disposition_path.read_text(encoding="utf-8")))
    source_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    disposition["conditions"][0]["final_decision"] = "pending_accountable_review"

    assert CHECKER.ash_bounded_condition_disposition_document_errors(
        disposition, source_manifest, ROOT
    ) == [
        "Ash bounded-condition disposition: transaction_backed_non_atomic_action must remain an "
        "accepted bounded production gate"
    ]


def test_quality_targets_and_capacity_recovery_evidence_are_source_bound() -> None:
    assert CHECKER.quality_target_recommendation_errors(ROOT) == []
    assert CHECKER.capacity_recovery_measurement_errors(ROOT) == []


def test_capacity_recovery_evidence_preserves_the_noisy_tenant_failure() -> None:
    evidence_path = (
        ROOT / "spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json"
    )
    recommendation_path = (
        ROOT / "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json"
    )
    evidence = copy.deepcopy(json.loads(evidence_path.read_text(encoding="utf-8")))
    recommendation = json.loads(recommendation_path.read_text(encoding="utf-8"))
    evidence["evaluation"]["checks"]["noisy_tenant_degradation"] = True
    evidence["evaluation"]["passed"] = True
    evidence["evaluation"]["disposition"] = "local_targets_passed_managed_confirmation_required"

    assert CHECKER.capacity_recovery_measurement_document_errors(
        evidence, recommendation, ROOT
    ) == ["capacity/recovery measurement: target evaluation does not preserve the measured failure"]


def test_tenant_fairness_evidence_is_source_bound_and_passes_local_gates() -> None:
    assert CHECKER.tenant_fairness_measurement_errors(ROOT) == []


def test_tenant_fairness_evidence_preserves_baseline_and_candidate_results() -> None:
    evidence_path = (
        ROOT / "spikes/ash-foundation-lab/priv/maintenance/tenant-fairness-measurement.json"
    )
    recommendation_path = (
        ROOT / "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json"
    )
    baseline_path = (
        ROOT / "spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json"
    )
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    recommendation = json.loads(recommendation_path.read_text(encoding="utf-8"))
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))

    stale_baseline = copy.deepcopy(evidence)
    stale_baseline["bindings"]["failed_capacity_recovery_sha256"] = "0" * 64
    assert "tenant-fairness measurement: failed baseline binding is stale" in (
        CHECKER.tenant_fairness_measurement_document_errors(
            stale_baseline, recommendation, baseline, ROOT
        )
    )

    failed_candidate = copy.deepcopy(evidence)
    failed_candidate["evaluation"]["checks"]["candidate_safety_contract"] = False
    failed_candidate["evaluation"]["passed"] = False
    failed_candidate["evaluation"]["disposition"] = "local_fairness_candidate_has_failed_gate"
    assert (
        "tenant-fairness measurement: candidate evaluation must preserve the passing local result"
        in (
            CHECKER.tenant_fairness_measurement_document_errors(
                failed_candidate, recommendation, baseline, ROOT
            )
        )
    )


def test_accepted_targets_and_capacity_followups_are_source_bound() -> None:
    assert CHECKER.phase0_followup_evidence_errors(ROOT) == []


def test_phase_one_core_requires_a_start_record_and_rejects_other_apps(
    tmp_path: Path,
) -> None:
    apps = tmp_path / "apps"
    (apps / "chimwemwe_core").mkdir(parents=True)

    assert CHECKER.phase_boundary_errors(tmp_path) == ["Phase 0 forbidden directory exists: apps"]

    start_record = tmp_path / CHECKER.PHASE1_CORE_START_RECORD
    start_record.parent.mkdir(parents=True)
    start_record.write_text("# Phase 1\n", encoding="utf-8")

    assert CHECKER.phase_boundary_errors(tmp_path) == []

    (apps / "attendance").mkdir()

    assert CHECKER.phase_boundary_errors(tmp_path) == [
        "Phase 1 slices 1A through 1F permit only apps/chimwemwe_core; unexpected apps: attendance"
    ]
