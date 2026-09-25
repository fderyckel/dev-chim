"""Validate Phase 0 repository, documentation, and decision conventions."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any
from urllib.parse import unquote

ALLOWED_ADR_STATUSES = {
    "Accepted",
    "Conditionally Accepted",
    "Deferred",
    "Proposed",
    "Rejected",
    "Superseded",
    "Template",
}

REQUIRED_PATHS = (
    ".githooks/pre-push",
    "README.md",
    "AGENTS.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "Brewfile",
    "mise.toml",
    "pyproject.toml",
    "uv.lock",
    "docs/README.md",
    "docs/architecture/README.md",
    "docs/architecture/core-foundation-boundary.md",
    "docs/architecture/module-activation-and-lifecycle.md",
    "docs/architecture/postgresql-availability-recovery-and-read-routing.md",
    "docs/architecture/quality-attribute-targets.md",
    "docs/architecture/tenant-placement-and-capacity.md",
    "docs/adr/README.md",
    "docs/adr/0000-template.md",
    "docs/security/threat-model.md",
    "docs/phase-0/README.md",
    "docs/phase-0/decision-register.md",
    "docs/phase-0/evidence/ash-bounded-condition-disposition.md",
    "docs/phase-0/evidence/ash-dependency-warning-baseline.md",
    "docs/phase-0/evidence/ash-nonpatch-upgrade-exercise.md",
    "docs/phase-0/evidence/ash-security-patch.md",
    "docs/phase-0/evidence/ash-upgrade-exercise.md",
    "docs/phase-0/evidence/capacity-and-recovery-measurement.md",
    "docs/phase-0/evidence/clean-checkout-rehearsal.md",
    "docs/phase-0/evidence/full-horizon-restore-measurement.md",
    "docs/phase-0/evidence/managed-postgresql-topology.md",
    "docs/phase-0/evidence/module-lifecycle.md",
    "docs/phase-0/evidence/postgresql-availability-and-burst.md",
    "docs/phase-0/evidence/quality-target-recommendation.md",
    "docs/phase-0/evidence/retained-data-migration-measurement.md",
    "docs/phase-0/evidence/precheckout-admission-measurement.md",
    "docs/phase-0/evidence/tenant-fairness-backpressure-measurement.md",
    "docs/phase-0/evidence/tenant-placement-capacity.md",
    "docs/phase-0/evidence/trusted-routing.md",
    "docs/phase-0/review-record.md",
    "docs/phase-1/README.md",
    "docs/phase-1/evidence/action-invocation.md",
    "docs/phase-1/evidence/core-foundation.md",
    "docs/phase-1/evidence/database-admission.md",
    "docs/phase-1/evidence/resource-descriptor.md",
    "docs/phase-1/evidence/trusted-persistence.md",
    "docs/development/migrations.md",
    "docs/plans/phase-1-core-foundation-plan.md",
    "tools/check_ash_dependency_warnings.py",
    "apps/chimwemwe_core/mix.exs",
    "apps/chimwemwe_core/lib/chimwemwe/platform.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/action_invocation.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/admission_error.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/database_admission.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/execution_context.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/invocation_error.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/persistence.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/persistence_error.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/persistence_runtime.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/placement_registry.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/resource.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/resource_contract.ex",
    "apps/chimwemwe_core/lib/chimwemwe/platform/resource_descriptor.ex",
    "apps/chimwemwe_core/lib/chimwemwe/repo.ex",
    "apps/chimwemwe_core/priv/repo/migrations/README.md",
    "apps/chimwemwe_core/priv/resource_snapshots/README.md",
    "config/config.exs",
    "mix.exs",
    "spikes/ash-foundation-lab/mix.exs",
    "spikes/ash-foundation-lab/mix.lock",
    "spikes/ash-foundation-lab/priv/maintenance/ash-dependency-warnings.json",
    "spikes/ash-foundation-lab/priv/maintenance/ash-bounded-condition-disposition.json",
    "spikes/ash-foundation-lab/priv/maintenance/ash-nonpatch-upgrade.json",
    "spikes/ash-foundation-lab/priv/maintenance/ash-security-patch.json",
    "spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json",
    "spikes/ash-foundation-lab/priv/maintenance/clean-checkout-rehearsal.json",
    "spikes/ash-foundation-lab/priv/maintenance/full-horizon-restore-measurement.json",
    "spikes/ash-foundation-lab/priv/maintenance/managed-postgresql-topology.json",
    "spikes/ash-foundation-lab/priv/maintenance/precheckout-admission-measurement.json",
    "spikes/ash-foundation-lab/priv/maintenance/quality-target-technical-approval.json",
    "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json",
    "spikes/ash-foundation-lab/priv/maintenance/retained-data-migration-measurement.json",
    "spikes/ash-foundation-lab/priv/maintenance/tenant-fairness-measurement.json",
    "spikes/ash-foundation-lab/typescript-client-review/package.json",
    "spikes/ash-foundation-lab/typescript-client-review/package-lock.json",
    "tools/measure_phase0_capacity_recovery.py",
    "tools/measure_phase0_full_horizon_restore.py",
    "tools/measure_phase0_precheckout_admission.py",
    "tools/measure_phase0_tenant_fairness.py",
    "tools/rehearse_phase0_clean_checkout.py",
)

REQUIRED_ADR_NUMBERS = {
    "0001",
    "0002",
    "0003",
    "0005",
    "0007",
    "0009",
    "0010",
    "0012",
    "0014",
    "0015",
    "0016",
    "0017",
    "0019",
}

REQUIRED_ADR_HEADINGS = (
    "## Context",
    "## Decision drivers",
    "## Considered options",
    "## Decision",
    "## Consequences",
    "## Security, privacy, operability, and migration effects",
    "## Validation evidence",
    "## Fallback and exit cost",
    "## Review triggers",
    "## Related records",
)

FORBIDDEN_PHASE0_DIRECTORIES = (
    "analytics",
    "apps",
    "infra/production",
    "services/ai-gateway",
    "services/scheduler",
    "web",
)

PHASE1_CORE_START_RECORD = "docs/phase-1/README.md"
PHASE1_ALLOWED_APPS = {"chimwemwe_core"}

IGNORED_DIRECTORY_NAMES = {".git", ".venv", "_build", "deps", "node_modules"}

LINK_PATTERN = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")
STATUS_PATTERN = re.compile(r"^- Status: (.+)$", re.MULTILINE)
ADR_FILENAME_PATTERN = re.compile(r"^(\d{4})-[a-z0-9-]+\.md$")
ADR_INDEX_PATTERN = re.compile(
    r"^\| \[(\d{4})\]\(([^)]+)\) \| [^|]+ \| ([^|]+) \|",
    re.MULTILINE,
)
PHASE0_DECISION_ADR_PATTERN = re.compile(
    r"^\| \[(\d{4})\]\(\.\./adr/([^)]+)\) \|",
    re.MULTILINE,
)
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
SEMVER_PATTERN = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def markdown_errors(path: Path, root: Path) -> list[str]:
    """Return structural and relative-link errors for one Markdown document."""
    errors: list[str] = []
    body = path.read_text(encoding="utf-8")
    lines = body.splitlines()

    if sum(line.startswith("# ") for line in lines) != 1:
        errors.append(f"{path.relative_to(root)}: expected exactly one H1")

    if any(line.endswith((" ", "\t")) for line in lines):
        errors.append(f"{path.relative_to(root)}: trailing whitespace")

    for raw_target in LINK_PATTERN.findall(body):
        target = raw_target.strip().split(maxsplit=1)[0]
        if target.startswith(("#", "http://", "https://", "mailto:")):
            continue
        relative_target = unquote(target.split("#", maxsplit=1)[0])
        if not relative_target:
            continue
        resolved = (path.parent / relative_target).resolve()
        if not resolved.exists():
            errors.append(f"{path.relative_to(root)}: broken relative link {relative_target!r}")

    return errors


def adr_errors(root: Path) -> list[str]:
    """Return errors in ADR numbering, status, headings, and the ADR index."""
    errors: list[str] = []
    adr_dir = root / "docs/adr"
    records: dict[str, tuple[Path, str]] = {}

    for path in sorted(adr_dir.glob("[0-9][0-9][0-9][0-9]-*.md")):
        match = ADR_FILENAME_PATTERN.match(path.name)
        if not match:
            errors.append(f"{path.relative_to(root)}: invalid ADR filename")
            continue

        number = match.group(1)
        if number in records:
            errors.append(f"duplicate ADR number {number}")
            continue

        body = path.read_text(encoding="utf-8")
        status_match = STATUS_PATTERN.search(body)
        if not status_match:
            errors.append(f"{path.relative_to(root)}: missing Status metadata")
            status = ""
        else:
            status = status_match.group(1).strip()
            if status not in ALLOWED_ADR_STATUSES:
                errors.append(f"{path.relative_to(root)}: invalid ADR status {status!r}")

        for heading in REQUIRED_ADR_HEADINGS:
            if heading not in body:
                errors.append(f"{path.relative_to(root)}: missing heading {heading!r}")

        records[number] = (path, status)

    missing_numbers = sorted(REQUIRED_ADR_NUMBERS - records.keys())
    if missing_numbers:
        errors.append(f"missing required ADR numbers: {', '.join(missing_numbers)}")

    index_body = (adr_dir / "README.md").read_text(encoding="utf-8")
    indexed: dict[str, tuple[str, str]] = {
        number: (target, status.strip())
        for number, target, status in ADR_INDEX_PATTERN.findall(index_body)
    }

    for number, (path, status) in records.items():
        index_entry = indexed.get(number)
        if index_entry is None:
            errors.append(f"ADR {number}: missing from docs/adr/README.md")
            continue
        target, index_status = index_entry
        if target != path.name:
            errors.append(f"ADR {number}: index target {target!r} != {path.name!r}")
        if index_status != status:
            errors.append(f"ADR {number}: index status {index_status!r} != {status!r}")

    return errors


def threat_model_errors(root: Path) -> list[str]:
    """Check that the Phase 0 threat register retains its mandatory columns."""
    path = root / "docs/security/threat-model.md"
    body = path.read_text(encoding="utf-8")
    errors: list[str] = []

    for threat_number in range(1, 17):
        threat_id = f"TM-{threat_number:02d}"
        matching_lines = [line for line in body.splitlines() if line.startswith(f"| {threat_id} |")]
        if len(matching_lines) != 1:
            errors.append(f"{path.relative_to(root)}: expected one row for {threat_id}")
            continue
        cells = [cell.strip() for cell in matching_lines[0].strip("|").split("|")]
        if len(cells) != 6 or any(not cell for cell in cells):
            errors.append(f"{path.relative_to(root)}: incomplete row for {threat_id}")

    return errors


def exit_review_errors(root: Path) -> list[str]:
    """Return blockers that are allowed during work but forbidden at Phase 0 exit."""
    errors: list[str] = []
    governed = (
        root / "docs/architecture/quality-attribute-targets.md",
        root / "docs/phase-0/evidence/module-lifecycle.md",
        root / "docs/phase-0/evidence/postgresql-availability-and-burst.md",
        root / "docs/phase-0/evidence/quality-targets-approval.md",
        root / "docs/phase-0/evidence/tenant-placement-capacity.md",
        root / "docs/phase-0/review-record.md",
    )
    placeholders = (
        "TARGET_REQUIRED",
        "OWNER_REQUIRED",
        "DATE_REQUIRED",
        "EVIDENCE_REQUIRED",
        "DECISION_REQUIRED",
        "NOT_RUN",
    )

    for path in governed:
        body = path.read_text(encoding="utf-8")
        present = [placeholder for placeholder in placeholders if placeholder in body]
        if present:
            errors.append(
                f"{path.relative_to(root)}: unresolved exit placeholders {', '.join(present)}"
            )

    decision_register = (root / "docs/phase-0/decision-register.md").read_text(encoding="utf-8")
    for _number, target in PHASE0_DECISION_ADR_PATTERN.findall(decision_register):
        path = root / "docs/adr" / target
        body = path.read_text(encoding="utf-8")
        status_match = STATUS_PATTERN.search(body)
        if status_match and status_match.group(1).strip() == "Proposed":
            errors.append(f"{path.relative_to(root)}: still Proposed at exit review")

    return errors


def phase_boundary_errors(root: Path) -> list[str]:
    """Keep the explicit early Phase 1 exception narrow and reviewable."""
    errors: list[str] = []
    phase1_started = (root / PHASE1_CORE_START_RECORD).exists()

    for relative_path in FORBIDDEN_PHASE0_DIRECTORIES:
        path = root / relative_path
        if not path.exists():
            continue

        if relative_path == "apps" and phase1_started:
            app_names = {entry.name for entry in path.iterdir() if entry.is_dir()}
            unexpected_apps = sorted(app_names - PHASE1_ALLOWED_APPS)
            if unexpected_apps:
                errors.append(
                    "Phase 1 slices 1A through 1F permit only apps/chimwemwe_core; "
                    f"unexpected apps: {', '.join(unexpected_apps)}"
                )
            continue

        errors.append(f"Phase 0 forbidden directory exists: {relative_path}")

    return errors


def locked_hex_versions(root: Path) -> dict[str, str]:
    lock_path = root / "spikes/ash-foundation-lab/mix.lock"
    if not lock_path.exists():
        return {}
    pattern = re.compile(
        r'^\s*"(?P<name>[a-z0-9_]+)": \{:hex, :[a-z0-9_]+, "(?P<version>[^"]+)"',
        re.MULTILINE,
    )
    return {
        match.group("name"): match.group("version")
        for match in pattern.finditer(lock_path.read_text(encoding="utf-8"))
    }


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ash_upgrade_document_errors(evidence: Any, root: Path) -> list[str]:
    """Validate the governed historical non-patch upgrade evidence."""
    prefix = "ash non-patch upgrade evidence"
    expected_top_level = {
        "schema_version",
        "status",
        "owner",
        "reviewed_on",
        "source_revision",
        "environment",
        "upgrade",
        "excluded_baselines",
        "release_review",
        "checks",
        "artifacts",
        "warnings",
        "result",
        "limits",
    }
    if not isinstance(evidence, dict) or set(evidence) != expected_top_level:
        return [f"{prefix}: unexpected top-level shape"]

    errors: list[str] = []
    if evidence["schema_version"] != 1 or evidence["status"] != "phase0_evidence":
        errors.append(f"{prefix}: unsupported schema or status")
    if not isinstance(evidence["owner"], str) or not evidence["owner"].strip():
        errors.append(f"{prefix}: owner must be non-empty")
    try:
        date.fromisoformat(evidence["reviewed_on"])
    except TypeError, ValueError:
        errors.append(f"{prefix}: reviewed_on must be an ISO date")
    if not isinstance(evidence["source_revision"], str) or not re.fullmatch(
        r"[0-9a-f]{40}", evidence["source_revision"]
    ):
        errors.append(f"{prefix}: source revision must be a full Git object id")
    if (
        not isinstance(evidence["environment"], dict)
        or not evidence["environment"]
        or any(
            not isinstance(value, str) or not value.strip()
            for value in evidence["environment"].values()
        )
    ):
        errors.append(f"{prefix}: environment must contain non-empty values")
    if (
        not isinstance(evidence["release_review"], list)
        or not evidence["release_review"]
        or any(not isinstance(item, str) or not item.strip() for item in evidence["release_review"])
    ):
        errors.append(f"{prefix}: release review must be recorded")

    upgrade = evidence["upgrade"]
    expected_upgrade_keys = {
        "package",
        "baseline",
        "candidate",
        "fixed_packages",
        "baseline_lock_sha256",
        "candidate_lock_sha256",
        "lock_delta_entries",
    }
    if not isinstance(upgrade, dict) or set(upgrade) != expected_upgrade_keys:
        errors.append(f"{prefix}: malformed upgrade scope")
    else:
        baseline_value = upgrade["baseline"]
        candidate_value = upgrade["candidate"]
        baseline_match = (
            SEMVER_PATTERN.fullmatch(baseline_value) if isinstance(baseline_value, str) else None
        )
        candidate_match = (
            SEMVER_PATTERN.fullmatch(candidate_value) if isinstance(candidate_value, str) else None
        )
        if not baseline_match or not candidate_match:
            errors.append(f"{prefix}: baseline and candidate must be three-part versions")
        else:
            baseline = tuple(map(int, baseline_match.groups()))
            candidate = tuple(map(int, candidate_match.groups()))
            if candidate <= baseline or candidate[:2] == baseline[:2]:
                errors.append(f"{prefix}: candidate must be a forward non-patch update")

        locked = locked_hex_versions(root)
        package = upgrade["package"]
        if not isinstance(package, str) or locked.get(package) != candidate_value:
            errors.append(f"{prefix}: candidate does not match the repository lock")
        fixed_packages = upgrade["fixed_packages"]
        fixed_packages_current = isinstance(fixed_packages, dict)
        if fixed_packages_current:
            for package_name, version in fixed_packages.items():
                locked_match = SEMVER_PATTERN.fullmatch(locked.get(package_name, ""))
                fixed_match = (
                    SEMVER_PATTERN.fullmatch(version) if isinstance(version, str) else None
                )
                if (
                    not locked_match
                    or not fixed_match
                    or tuple(map(int, locked_match.groups()))
                    < tuple(map(int, fixed_match.groups()))
                ):
                    fixed_packages_current = False
                    break
        if not fixed_packages_current:
            errors.append(f"{prefix}: fixed framework packages are newer than the lock")
        if upgrade["lock_delta_entries"] != [package]:
            errors.append(f"{prefix}: lock delta must contain only the upgraded package")
        for field in ("baseline_lock_sha256", "candidate_lock_sha256"):
            if not isinstance(upgrade[field], str) or not SHA256_PATTERN.fullmatch(upgrade[field]):
                errors.append(f"{prefix}: {field} is malformed")

    required_checks = {
        "compile_warnings_as_errors",
        "hex_security_audit",
        "unused_dependency_check",
        "generated_migration_drift",
        "openapi_drift",
        "resource_descriptor_drift",
        "same_schema_full_test_suite",
    }
    checks = evidence["checks"]
    if (
        not isinstance(checks, list)
        or {check.get("id") for check in checks if isinstance(check, dict)} != required_checks
    ):
        errors.append(f"{prefix}: required before/after checks are incomplete")
    elif any(
        check.get("baseline") != check.get("candidate")
        or check.get("baseline") not in {"pass", "94_passed"}
        for check in checks
    ):
        errors.append(f"{prefix}: a before/after check did not pass identically")

    artifacts = evidence["artifacts"]
    expected_artifacts = {
        "generated_migration_bundle_sha256",
        "openapi_sha256",
        "resource_descriptor_sha256",
    }
    if not isinstance(artifacts, dict) or set(artifacts) != expected_artifacts:
        errors.append(f"{prefix}: artifact comparison is incomplete")
    else:
        for name, comparison in artifacts.items():
            if (
                not isinstance(comparison, dict)
                or set(comparison) != {"baseline", "candidate"}
                or comparison["baseline"] != comparison["candidate"]
                or not isinstance(comparison["candidate"], str)
                or not SHA256_PATTERN.fullmatch(comparison["candidate"])
            ):
                errors.append(f"{prefix}: {name} did not remain byte-stable")

    warnings = evidence["warnings"]
    if (
        not isinstance(warnings, dict)
        or warnings.get("baseline_groups") != warnings.get("candidate_groups")
        or warnings.get("added") != warnings.get("removed")
        or warnings.get("disposition") != "source_location_only"
        or not isinstance(warnings.get("moved_locations"), list)
        or len(warnings["moved_locations"]) != warnings.get("added")
    ):
        errors.append(f"{prefix}: warning delta is not fully dispositioned")

    excluded = evidence["excluded_baselines"]
    if not isinstance(excluded, list) or {
        item.get("package") for item in excluded if isinstance(item, dict)
    } != {"ash", "ash_postgres"}:
        errors.append(f"{prefix}: unsafe preceding-minor exclusions are incomplete")
    if evidence["result"] != "pass_with_bounded_remediation":
        errors.append(f"{prefix}: result must preserve bounded remediation")
    if (
        not isinstance(evidence["limits"], list)
        or not evidence["limits"]
        or any(not isinstance(item, str) or not item.strip() for item in evidence["limits"])
    ):
        errors.append(f"{prefix}: limits must be recorded")

    return errors


def ash_upgrade_evidence_errors(root: Path) -> list[str]:
    path = root / "spikes/ash-foundation-lab/priv/maintenance/ash-nonpatch-upgrade.json"
    try:
        evidence = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"ash non-patch upgrade evidence: cannot read artifact: {error}"]
    return ash_upgrade_document_errors(evidence, root)


def retained_data_measurement_document_errors(evidence: Any, root: Path) -> list[str]:
    """Validate the retained-data scale measurement and its source bindings."""
    prefix = "retained-data migration measurement"
    expected_top_level = {
        "schema_version",
        "status",
        "owner",
        "measured_on",
        "source",
        "command",
        "envelope",
        "environment",
        "methodology",
        "runs",
        "summary",
        "result",
        "limits",
    }
    if not isinstance(evidence, dict) or set(evidence) != expected_top_level:
        return [f"{prefix}: unexpected top-level shape"]

    errors: list[str] = []
    if evidence["schema_version"] != 1 or evidence["status"] != "phase0_evidence":
        errors.append(f"{prefix}: unsupported schema or status")
    if evidence["owner"] != "Platform engineering":
        errors.append(f"{prefix}: owner is not explicit")
    try:
        date.fromisoformat(evidence["measured_on"])
    except TypeError, ValueError:
        errors.append(f"{prefix}: measured_on must be an ISO date")

    errors.extend(_retained_data_source_errors(evidence["source"], root, prefix))

    if not isinstance(evidence["command"], str) or not all(
        fragment in evidence["command"]
        for fragment in (
            "phase0.retained_data.measure",
            "--primary-rows 1280000",
            "--control-rows 32000",
            "--repetitions 3",
        )
    ):
        errors.append(f"{prefix}: exact measurement command is missing")

    expected_envelope = {
        "approved_production_target": False,
        "basis": (
            "one synthetic 800-learner school-year at 200 days and eight "
            "attendance opportunities, plus a separate control tenant"
        ),
        "control_tenant_rows": 32_000,
        "primary_tenant_rows": 1_280_000,
        "repetitions": 3,
        "total_rows_per_run": 1_312_000,
    }
    if evidence["envelope"] != expected_envelope:
        errors.append(f"{prefix}: planning envelope changed or claims production approval")

    environment = evidence["environment"]
    expected_environment_keys = {
        "architecture",
        "cpu",
        "elixir",
        "erlang_otp",
        "memory_bytes",
        "operating_system",
        "scheduler_count",
    }
    if (
        not isinstance(environment, dict)
        or set(environment) != expected_environment_keys
        or any(not isinstance(value, str) or not value.strip() for value in environment.values())
    ):
        errors.append(f"{prefix}: local environment record is incomplete")

    methodology = evidence["methodology"]
    if (
        not isinstance(methodology, dict)
        or methodology.get("backfill_batch_size") != 100
        or methodology.get("lock_timeout") != "250ms"
        or methodology.get("migration_lock_retry")
        != {
            "delay_ms": 250,
            "maximum_attempts": 120,
            "rule": (
                "retry only PostgreSQL lock_not_available after the failed transaction rolls back"
            ),
        }
        or any(
            not isinstance(methodology.get(field), str) or not methodology[field].strip()
            for field in (
                "batch_latency_percentile_method",
                "database_lifecycle",
                "support_index",
                "tenant_safety",
            )
        )
    ):
        errors.append(f"{prefix}: bounded methodology is incomplete")

    runs = evidence["runs"]
    if not isinstance(runs, list) or len(runs) != 3:
        errors.append(f"{prefix}: expected three complete repetitions")
    else:
        for expected_repetition, run in enumerate(runs, start=1):
            errors.extend(_retained_data_run_errors(run, expected_repetition, prefix))

    errors.extend(_retained_data_summary_errors(evidence["summary"], prefix))

    if evidence["result"] != "measured_with_bounded_remediation":
        errors.append(f"{prefix}: result must retain bounded remediation")
    if (
        not isinstance(evidence["limits"], list)
        or len(evidence["limits"]) < 5
        or any(not isinstance(limit, str) or not limit.strip() for limit in evidence["limits"])
    ):
        errors.append(f"{prefix}: measurement limits are incomplete")

    return errors


def _retained_data_source_errors(source: Any, root: Path, prefix: str) -> list[str]:
    expected_sources = {
        "lib/ash_foundation_lab/retained_data_migration.ex",
        "lib/ash_foundation_lab/retained_data_migration_measurement.ex",
        "lib/mix/tasks/phase0.retained_data.measure.ex",
        (
            "priv/retained_data_migration_rehearsal/migrations/"
            "20260915010000_expand_foundation_record_name.exs"
        ),
        (
            "priv/retained_data_migration_rehearsal/migrations/"
            "20260915020000_enforce_foundation_record_dual_write.exs"
        ),
        (
            "priv/retained_data_migration_rehearsal/migrations/"
            "20260915030000_validate_foundation_record_name.exs"
        ),
        (
            "priv/retained_data_migration_rehearsal/migrations/"
            "20260915040000_contract_foundation_record_name.exs"
        ),
    }
    if not isinstance(source, dict) or set(source) != {
        "artifacts_sha256",
        "git_revision",
        "working_tree",
    }:
        return [f"{prefix}: malformed source record"]

    errors: list[str] = []
    if not isinstance(source["git_revision"], str) or not re.fullmatch(
        r"[0-9a-f]{40}", source["git_revision"]
    ):
        errors.append(f"{prefix}: source revision must be a full Git object id")
    if source["working_tree"] not in {"clean", "dirty"}:
        errors.append(f"{prefix}: working-tree state is invalid")

    artifacts = source["artifacts_sha256"]
    if not isinstance(artifacts, dict) or set(artifacts) != expected_sources:
        errors.append(f"{prefix}: measured source set is incomplete")
        return errors

    spike_root = root / "spikes/ash-foundation-lab"
    for relative_path, digest in artifacts.items():
        path = spike_root / relative_path
        if not isinstance(digest, str) or not SHA256_PATTERN.fullmatch(digest):
            errors.append(f"{prefix}: malformed digest for {relative_path}")
        elif not path.is_file() or file_sha256(path) != digest:
            errors.append(f"{prefix}: measured source drifted: {relative_path}")
    return errors


def _retained_data_run_errors(run: Any, repetition: int, prefix: str) -> list[str]:
    run_prefix = f"{prefix}: repetition {repetition}"
    expected_keys = {
        "repetition",
        "environment",
        "rows",
        "timings_ms",
        "migration_lock_attempts",
        "backfill",
        "relation_bytes",
        "wal_bytes",
        "retained_fingerprint",
        "assertions",
    }
    if not isinstance(run, dict) or set(run) != expected_keys:
        return [f"{run_prefix} has an unexpected shape"]

    errors: list[str] = []
    if run["repetition"] != repetition:
        errors.append(f"{run_prefix} has the wrong repetition number")
    if run["rows"] != {
        "control_tenant": 32_000,
        "primary_tenant": 1_280_000,
        "total": 1_312_000,
    }:
        errors.append(f"{run_prefix} has the wrong row envelope")

    errors.extend(_retained_data_database_environment_errors(run["environment"], run_prefix))
    errors.extend(_retained_data_timing_errors(run, run_prefix))
    errors.extend(_retained_data_backfill_errors(run["backfill"], run_prefix))
    errors.extend(_retained_data_size_errors(run["relation_bytes"], run_prefix))
    errors.extend(_retained_data_wal_errors(run["wal_bytes"], run_prefix))

    fingerprint = run["retained_fingerprint"]
    if (
        not isinstance(fingerprint, dict)
        or fingerprint.get("rows") != 1_312_000
        or not isinstance(fingerprint.get("fingerprint"), str)
        or not fingerprint["fingerprint"]
    ):
        errors.append(f"{run_prefix} has invalid retained-data fingerprint")

    expected_assertions = {
        "canonical_column_not_null",
        "control_tenant_untouched_during_primary_backfill",
        "legacy_column_removed",
        "non_empty_constraint_validated",
        "presence_constraint_validated",
        "retained_fingerprint_unchanged",
        "support_index_removed",
        "tenant_counts_preserved",
        "values_match",
    }
    assertions = run["assertions"]
    if (
        not isinstance(assertions, dict)
        or set(assertions) != expected_assertions
        or not all(value is True for value in assertions.values())
    ):
        errors.append(f"{run_prefix} has a failed or missing safety assertion")
    return errors


def _retained_data_database_environment_errors(environment: Any, run_prefix: str) -> list[str]:
    required_settings = {
        "fsync",
        "full_page_writes",
        "max_connections",
        "shared_buffers",
        "synchronous_commit",
        "wal_level",
    }
    if (
        not isinstance(environment, dict)
        or set(environment) != {"postgresql_server_version", "settings"}
        or not isinstance(environment["postgresql_server_version"], str)
        or not environment["postgresql_server_version"].strip()
        or not isinstance(environment["settings"], dict)
        or set(environment["settings"]) != required_settings
        or any(
            not isinstance(value, str) or not value.strip()
            for value in environment["settings"].values()
        )
    ):
        return [f"{run_prefix} has incomplete PostgreSQL settings"]
    return []


def _retained_data_timing_errors(run: dict[str, Any], run_prefix: str) -> list[str]:
    timing_keys = {
        "contract",
        "control_backfill",
        "enforce",
        "expand",
        "primary_backfill",
        "seed",
        "support_index_build",
        "support_index_drop",
        "validate",
    }
    timings = run["timings_ms"]
    errors: list[str] = []
    if (
        not isinstance(timings, dict)
        or set(timings) != timing_keys
        or any(not isinstance(value, (int, float)) or value <= 0 for value in timings.values())
    ):
        errors.append(f"{run_prefix} has incomplete timings")

    attempts = run["migration_lock_attempts"]
    if (
        not isinstance(attempts, dict)
        or set(attempts) != {"contract", "enforce", "expand", "validate"}
        or any(not isinstance(value, int) or not 1 <= value <= 120 for value in attempts.values())
    ):
        errors.append(f"{run_prefix} has invalid lock-attempt evidence")
    return errors


def _retained_data_backfill_errors(backfill: Any, run_prefix: str) -> list[str]:
    if not isinstance(backfill, dict) or set(backfill) != {
        "batch_size",
        "control",
        "primary",
        "support_index",
    }:
        return [f"{run_prefix} has incomplete backfill evidence"]

    errors: list[str] = []
    if backfill["batch_size"] != 100:
        errors.append(f"{run_prefix} changed the bounded batch size")
    expected_backfills = {
        "primary": {"rows": 1_280_000, "batches": 12_800},
        "control": {"rows": 32_000, "batches": 320},
    }
    for tenant, expected in expected_backfills.items():
        measured = backfill[tenant]
        latency = measured.get("batch_latency_ms") if isinstance(measured, dict) else None
        if (
            not isinstance(measured, dict)
            or measured.get("rows") != expected["rows"]
            or measured.get("batches") != expected["batches"]
            or not isinstance(measured.get("elapsed_ms"), (int, float))
            or measured["elapsed_ms"] <= 0
            or not isinstance(measured.get("rows_per_second"), (int, float))
            or measured["rows_per_second"] <= 0
            or not isinstance(latency, dict)
            or set(latency) != {"p50", "p95", "p99", "max"}
            or any(not isinstance(value, (int, float)) or value <= 0 for value in latency.values())
        ):
            errors.append(f"{run_prefix} has invalid {tenant} backfill evidence")

    if backfill["support_index"] != {
        "columns": ["tenant_id", "inserted_at", "id"],
        "creation": "concurrent",
        "name": "foundation_records_canonical_name_backfill_index",
        "predicate": "canonical_name IS NULL",
    }:
        errors.append(f"{run_prefix} has the wrong support-index contract")
    return errors


def _retained_data_size_errors(relation_bytes: Any, run_prefix: str) -> list[str]:
    if not isinstance(relation_bytes, dict) or set(relation_bytes) != {
        "after_backfill",
        "after_contract",
        "after_seed",
        "with_support_index",
    }:
        return [f"{run_prefix} has incomplete relation-size evidence"]

    errors: list[str] = []
    for phase, sizes in relation_bytes.items():
        if (
            not isinstance(sizes, dict)
            or set(sizes) != {"indexes", "table", "total"}
            or any(not isinstance(value, int) or value <= 0 for value in sizes.values())
            or sizes["total"] < sizes["table"] + sizes["indexes"]
        ):
            errors.append(f"{run_prefix} has invalid relation sizes for {phase}")
    return errors


def _retained_data_wal_errors(wal_bytes: Any, run_prefix: str) -> list[str]:
    expected_keys = {
        "backfill",
        "contract",
        "enforce",
        "expand",
        "seed",
        "support_index_build",
        "support_index_drop",
        "total",
        "validate",
    }
    if (
        not isinstance(wal_bytes, dict)
        or set(wal_bytes) != expected_keys
        or any(not isinstance(value, int) or value < 0 for value in wal_bytes.values())
        or wal_bytes.get("total", 0) <= 0
    ):
        return [f"{run_prefix} has invalid WAL evidence"]
    return []


def _retained_data_summary_errors(summary: Any, prefix: str) -> list[str]:
    expected_keys = {
        "primary_backfill_rows_per_second",
        "primary_backfill_elapsed_ms",
        "support_index_build_ms",
        "total_wal_bytes",
        "final_relation_bytes",
    }
    if not isinstance(summary, dict) or set(summary) != expected_keys:
        return [f"{prefix}: repeated-run summary is incomplete"]

    errors: list[str] = []
    for metric, distribution in summary.items():
        if (
            not isinstance(distribution, dict)
            or set(distribution) != {"min", "median", "max"}
            or not all(
                isinstance(distribution[key], (int, float)) and distribution[key] > 0
                for key in ("min", "median", "max")
            )
            or not distribution["min"] <= distribution["median"] <= distribution["max"]
        ):
            errors.append(f"{prefix}: invalid summary distribution for {metric}")
    return errors


def retained_data_measurement_evidence_errors(root: Path) -> list[str]:
    path = (
        root / "spikes/ash-foundation-lab/priv/maintenance/retained-data-migration-measurement.json"
    )
    try:
        evidence = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"retained-data migration measurement: cannot read artifact: {error}"]
    return retained_data_measurement_document_errors(evidence, root)


def ash_bounded_condition_disposition_document_errors(
    disposition: Any, source_manifest: Any, root: Path
) -> list[str]:
    """Validate the accountable decision for every owned Ash boundary."""
    prefix = "Ash bounded-condition disposition"
    expected_top_level = {
        "schema_version",
        "status",
        "prepared_on",
        "scope",
        "source_manifest",
        "source_manifest_sha256",
        "recommendation",
        "conditions",
    }
    if not isinstance(disposition, dict) or set(disposition) != expected_top_level:
        return [f"{prefix}: unexpected top-level shape"]

    errors: list[str] = []
    if (
        disposition["schema_version"] != 1
        or disposition["status"] != "conditionally_accepted"
        or disposition["scope"] != "ADR 0002 Ash adoption bounded conditions"
    ):
        errors.append(f"{prefix}: unsupported schema, status, or scope")
    try:
        date.fromisoformat(disposition["prepared_on"])
    except TypeError, ValueError:
        errors.append(f"{prefix}: prepared_on must be an ISO date")

    manifest_relative_path = "spikes/ash-foundation-lab/priv/maintenance/owned-boundaries.json"
    manifest_path = root / manifest_relative_path
    if (
        disposition["source_manifest"] != manifest_relative_path
        or not manifest_path.is_file()
        or disposition["source_manifest_sha256"] != file_sha256(manifest_path)
    ):
        errors.append(f"{prefix}: source manifest binding is stale or invalid")

    recommendation = disposition["recommendation"]
    expected_recommendation_keys = {
        "outcome",
        "binding",
        "rationale",
        "required_reviewers",
        "final_decision",
        "accepted_by",
        "decided_on",
    }
    required_reviewers = {
        "Architecture review group",
        "Platform engineering",
        "Web engineering",
        "Security/privacy",
        "Product/operations",
    }
    if not isinstance(recommendation, dict) or set(recommendation) != expected_recommendation_keys:
        errors.append(f"{prefix}: malformed recommendation")
    elif (
        recommendation["outcome"] != "conditionally_accepted"
        or recommendation["binding"] is not True
        or recommendation["final_decision"] != "conditionally_accepted"
        or recommendation["accepted_by"] != "François — Project Owner"
        or recommendation["decided_on"] != "2026-09-16"
        or not isinstance(recommendation["required_reviewers"], list)
        or set(recommendation["required_reviewers"]) != required_reviewers
        or not isinstance(recommendation["rationale"], str)
        or not recommendation["rationale"].strip()
    ):
        errors.append(f"{prefix}: accountable conditional-acceptance decision is invalid")

    if not isinstance(source_manifest, dict) or not isinstance(
        source_manifest.get("boundaries"), list
    ):
        return [*errors, f"{prefix}: owned-boundary manifest is malformed"]

    boundaries = {
        boundary.get("id"): boundary
        for boundary in source_manifest["boundaries"]
        if isinstance(boundary, dict) and isinstance(boundary.get("id"), str)
    }
    conditions = disposition["conditions"]
    if not isinstance(conditions, list) or {
        condition.get("id") for condition in conditions if isinstance(condition, dict)
    } != set(boundaries):
        return [*errors, f"{prefix}: conditions do not match the owned-boundary manifest"]

    expected_condition_keys = {
        "id",
        "classification",
        "owner_role",
        "proposed_disposition",
        "rationale",
        "production_gate",
        "verification_method",
        "fallback_trigger",
        "recheck_trigger",
        "evidence",
        "required_reviewers",
        "final_decision",
        "accountable_person",
        "decision_due_on",
        "expires_on",
    }
    for condition in conditions:
        condition_id = condition["id"] if isinstance(condition, dict) else "unknown"
        item_prefix = f"{prefix}: {condition_id}"
        if not isinstance(condition, dict) or set(condition) != expected_condition_keys:
            errors.append(f"{item_prefix} has an unexpected shape")
            continue

        boundary = boundaries[condition_id]
        if (
            condition["classification"] != boundary.get("classification")
            or condition["owner_role"] != boundary.get("owner")
            or condition["production_gate"] != boundary.get("closure_gate")
            or condition["recheck_trigger"] != boundary.get("recheck_trigger")
        ):
            errors.append(f"{item_prefix} drifted from its owned boundary")

        if (
            condition["proposed_disposition"] != "retain_as_bounded_prerequisite"
            or condition["final_decision"] != "accepted_as_bounded_production_gate"
            or condition["accountable_person"] != "François — Platform Owner"
            or condition["decision_due_on"] != "2026-09-16"
            or condition["expires_on"] != "2026-12-15"
        ):
            errors.append(f"{item_prefix} must remain an accepted bounded production gate")

        text_fields = ("rationale", "fallback_trigger")
        if any(
            not isinstance(condition[field], str) or not condition[field].strip()
            for field in text_fields
        ):
            errors.append(f"{item_prefix} has incomplete reasoning or fallback")

        methods = condition["verification_method"]
        if (
            not isinstance(methods, list)
            or len(methods) < 2
            or any(not isinstance(method, str) or not method.strip() for method in methods)
        ):
            errors.append(f"{item_prefix} has incomplete verification methods")

        reviewers = condition["required_reviewers"]
        boundary_requires_web_review = condition["owner_role"] == "Platform and web engineering"
        if (
            not isinstance(reviewers, list)
            or "Architecture review group" not in reviewers
            or "Platform engineering" not in reviewers
            or (boundary_requires_web_review and "Web engineering" not in reviewers)
            or not set(reviewers) <= required_reviewers
        ):
            errors.append(f"{item_prefix} has invalid required reviewers")

        evidence_paths = condition["evidence"]
        if not isinstance(evidence_paths, list) or not evidence_paths:
            errors.append(f"{item_prefix} has no evidence")
        elif any(
            not isinstance(evidence_path, str)
            or not evidence_path.startswith("docs/")
            or not (root / evidence_path.split("#", maxsplit=1)[0]).is_file()
            for evidence_path in evidence_paths
        ):
            errors.append(f"{item_prefix} references missing or non-repository evidence")

    return errors


def ash_bounded_condition_disposition_errors(root: Path) -> list[str]:
    disposition_path = (
        root / "spikes/ash-foundation-lab/priv/maintenance/ash-bounded-condition-disposition.json"
    )
    manifest_path = root / "spikes/ash-foundation-lab/priv/maintenance/owned-boundaries.json"
    try:
        disposition = json.loads(disposition_path.read_text(encoding="utf-8"))
        source_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"Ash bounded-condition disposition: cannot read artifact: {error}"]
    return ash_bounded_condition_disposition_document_errors(disposition, source_manifest, root)


def quality_target_recommendation_document_errors(recommendation: Any) -> list[str]:
    """Validate the non-binding numeric quality-target recommendation."""
    prefix = "quality-target recommendation"
    expected_keys = {
        "schema_version",
        "status",
        "prepared_on",
        "scope",
        "profile",
        "targets",
        "approval",
        "limits",
    }
    if not isinstance(recommendation, dict) or set(recommendation) != expected_keys:
        return [f"{prefix}: unexpected top-level shape"]

    errors: list[str] = []
    if (
        recommendation["schema_version"] != 1
        or recommendation["status"] != "review_ready_pending_accountable_decision"
        or recommendation["scope"] != "Phase 0 quality-attribute target recommendation"
    ):
        errors.append(f"{prefix}: unsupported schema, status, or scope")
    try:
        date.fromisoformat(recommendation["prepared_on"])
    except TypeError, ValueError:
        errors.append(f"{prefix}: prepared_on must be an ISO date")

    expected_profile = {
        "name": "five_school_planning_envelope",
        "tenants": 5,
        "learners": 8200,
        "attendance_facts_per_period": 8200,
        "attendance_facts_per_year": 13120000,
        "planning_horizon_years": 10,
        "planning_horizon_attendance_facts": 131200000,
        "peak_window_seconds": 30,
        "session_batch_size": 25,
        "session_batches_per_period": 328,
        "approved_business_forecast": False,
    }
    if recommendation["profile"] != expected_profile:
        errors.append(f"{prefix}: planning envelope changed or claims business approval")

    expected_target_ids = {
        "interactive_api_reads",
        "interactive_mutations",
        "peak_domain_writes",
        "user_visible_web",
        "scale",
        "tenant_placement",
        "database_connections",
        "oltp_footprint",
        "read_consistency",
        "asynchronous_continuity",
        "report_campaigns",
        "files",
        "database_ha",
        "database_recovery",
        "object_recovery",
        "availability",
    }
    targets = recommendation["targets"]
    if (
        not isinstance(targets, list)
        or {target.get("id") for target in targets if isinstance(target, dict)}
        != expected_target_ids
    ):
        errors.append(f"{prefix}: target coverage is incomplete")
    else:
        for target in targets:
            if (
                set(target) != {"id", "owner_role", "metrics", "measurement"}
                or not isinstance(target["owner_role"], str)
                or not target["owner_role"].strip()
                or not isinstance(target["metrics"], dict)
                or not target["metrics"]
                or any(
                    not isinstance(value, (int, float)) or value < 0
                    for value in target["metrics"].values()
                )
                or not isinstance(target["measurement"], str)
                or not target["measurement"].strip()
            ):
                errors.append(f"{prefix}: malformed target {target.get('id', 'unknown')}")

    approval = recommendation["approval"]
    if approval != {
        "final_decision": "pending_accountable_review",
        "accountable_people": None,
        "decided_on": None,
        "review_due_on": None,
    }:
        errors.append(f"{prefix}: approval must remain explicitly pending")

    critical_metrics = {
        target["id"]: target["metrics"] for target in targets if isinstance(target, dict)
    }
    if (
        critical_metrics.get("peak_domain_writes", {}).get("committed_facts_per_second_min") != 550
        or critical_metrics.get("tenant_placement", {}).get(
            "other_tenant_p95_degradation_percent_max"
        )
        != 20
        or critical_metrics.get("database_ha", {}).get("committed_write_rpo_bytes_max") != 0
        or critical_metrics.get("database_ha", {}).get("failover_rto_seconds_max") != 120
        or critical_metrics.get("database_recovery", {}).get("pitr_rto_seconds_max") != 14400
    ):
        errors.append(f"{prefix}: measured critical gates changed")
    if (
        not isinstance(recommendation["limits"], list)
        or len(recommendation["limits"]) < 4
        or any(
            not isinstance(limit, str) or not limit.strip() for limit in recommendation["limits"]
        )
    ):
        errors.append(f"{prefix}: limits are incomplete")
    return errors


def quality_target_recommendation_errors(root: Path) -> list[str]:
    path = root / "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json"
    try:
        recommendation = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"quality-target recommendation: cannot read artifact: {error}"]
    return quality_target_recommendation_document_errors(recommendation)


def capacity_recovery_measurement_document_errors(
    evidence: Any, recommendation: Any, root: Path
) -> list[str]:
    """Validate the source-bound local capacity and recovery evidence."""
    prefix = "capacity/recovery measurement"
    expected_keys = {
        "schema_version",
        "status",
        "measured_on",
        "source",
        "command",
        "target_recommendation_sha256",
        "environment",
        "envelope",
        "capacity",
        "recovery",
        "evaluation",
        "limits",
    }
    if not isinstance(evidence, dict) or set(evidence) != expected_keys:
        return [f"{prefix}: unexpected top-level shape"]

    errors: list[str] = []
    if evidence["schema_version"] != 1 or evidence["status"] != "phase0_local_evidence":
        errors.append(f"{prefix}: unsupported schema or status")
    try:
        date.fromisoformat(evidence["measured_on"])
    except TypeError, ValueError:
        errors.append(f"{prefix}: measured_on must be an ISO date")

    target_path = (
        root / "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json"
    )
    if evidence["target_recommendation_sha256"] != file_sha256(target_path) or evidence[
        "envelope"
    ] != recommendation.get("profile"):
        errors.append(f"{prefix}: target recommendation binding is stale")

    expected_sources = {
        "tools/measure_phase0_capacity_recovery.py",
        "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json",
    }
    source = evidence["source"]
    if (
        not isinstance(source, dict)
        or set(source) != {"git_revision", "working_tree", "artifacts_sha256"}
        or not isinstance(source["git_revision"], str)
        or not re.fullmatch(r"[0-9a-f]{40}", source["git_revision"])
        or source["working_tree"] not in {"clean", "dirty"}
        or not isinstance(source["artifacts_sha256"], dict)
        or set(source["artifacts_sha256"]) != expected_sources
    ):
        errors.append(f"{prefix}: malformed source record")
    else:
        for relative_path, digest in source["artifacts_sha256"].items():
            if (
                not isinstance(digest, str)
                or not SHA256_PATTERN.fullmatch(digest)
                or not (root / relative_path).is_file()
                or file_sha256(root / relative_path) != digest
            ):
                errors.append(f"{prefix}: measured source drifted: {relative_path}")

    if not isinstance(evidence["command"], str) or not all(
        fragment in evidence["command"]
        for fragment in ("measure_phase0_capacity_recovery.py", "--repetitions 3", "1312000")
    ):
        errors.append(f"{prefix}: exact measurement command is missing")

    environment = evidence["environment"]
    if (
        not isinstance(environment, dict)
        or environment.get("postgresql_version") != "18.6 (Homebrew)"
        or environment.get("postgresql_settings", {}).get("fsync") != "on"
        or environment.get("postgresql_settings", {}).get("archive_mode") != "on"
        or environment.get("postgresql_settings", {}).get("wal_level") != "replica"
    ):
        errors.append(f"{prefix}: environment or durability settings are incomplete")

    capacity = evidence["capacity"]
    runs = capacity.get("runs") if isinstance(capacity, dict) else None
    if not isinstance(runs, list) or len(runs) != 3:
        errors.append(f"{prefix}: expected three capacity repetitions")
    else:
        expected_counts = {
            "batches": 328,
            "facts": 8200,
            "audit_events": 328,
            "outbox_events": 328,
        }
        for repetition, run_item in enumerate(runs, start=1):
            if (
                not isinstance(run_item, dict)
                or run_item.get("repetition") != repetition
                or run_item.get("bounded", {}).get("counts") != expected_counts
                or run_item.get("bounded", {}).get("facts") != 8200
                or run_item.get("bounded", {}).get("facts_per_second", 0) <= 0
                or run_item.get("unbatched_comparison", {}).get("counts", {}).get("facts") != 8200
                or not all(run_item.get("assertions", {}).values())
            ):
                errors.append(f"{prefix}: capacity repetition {repetition} is incomplete")

    noisy = capacity.get("noisy_tenant", {}) if isinstance(capacity, dict) else {}
    connection = capacity.get("connection_exhaustion", {}) if isinstance(capacity, dict) else {}
    if (
        not isinstance(noisy.get("runs"), list)
        or len(noisy["runs"]) != 3
        or noisy.get("other_tenant_p95_degradation_percent", {}).get("max", 0) <= 20
    ):
        errors.append(f"{prefix}: noisy-tenant failed-target evidence is incomplete")
    if (
        connection.get("rejected_attempts", 0) < 1
        or connection.get("rejected_before_transaction") is not True
    ):
        errors.append(f"{prefix}: connection exhaustion did not fail early")

    recovery = evidence["recovery"]
    pitr = recovery.get("pitr", {}) if isinstance(recovery, dict) else {}
    replica = recovery.get("replica", {}) if isinstance(recovery, dict) else {}
    failover = recovery.get("failover", {}) if isinstance(recovery, dict) else {}
    if (
        pitr.get("retained_rows") != 1312000
        or pitr.get("planning_horizon_fraction") != 0.01
        or not all(pitr.get("assertions", {}).values())
    ):
        errors.append(f"{prefix}: PITR evidence is incomplete")
    if (
        replica.get("paused_replay", {}).get("security_sensitive_route_used_stale_state")
        is not False
        or replica.get("standby_outage", {}).get("bounded_staleness_route_decision") != "reject"
        or replica.get("recovery_conflict", {}).get("long_query_cancelled") is not True
    ):
        errors.append(f"{prefix}: replica failure evidence is incomplete")
    if (
        failover.get("committed_write_rpo_bytes") != 0
        or failover.get("missing_outbox_events") != 0
        or failover.get("duplicate_outbox_events") != 0
        or not all(failover.get("assertions", {}).values())
    ):
        errors.append(f"{prefix}: failover safety evidence is incomplete")

    evaluation = evidence["evaluation"]
    checks = evaluation.get("checks", {}) if isinstance(evaluation, dict) else {}
    if (
        evaluation.get("passed") is not False
        or evaluation.get("disposition") != "local_measurement_has_failed_target"
        or checks.get("noisy_tenant_degradation") is not False
        or any(
            value is not True for key, value in checks.items() if key != "noisy_tenant_degradation"
        )
    ):
        errors.append(f"{prefix}: target evaluation does not preserve the measured failure")
    if (
        not isinstance(evidence["limits"], list)
        or len(evidence["limits"]) < 5
        or any(not isinstance(limit, str) or not limit.strip() for limit in evidence["limits"])
    ):
        errors.append(f"{prefix}: measurement limits are incomplete")
    return errors


def capacity_recovery_measurement_errors(root: Path) -> list[str]:
    evidence_path = (
        root / "spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json"
    )
    recommendation_path = (
        root / "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json"
    )
    try:
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
        recommendation = json.loads(recommendation_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"capacity/recovery measurement: cannot read artifact: {error}"]
    return capacity_recovery_measurement_document_errors(evidence, recommendation, root)


def _measurement_distribution(values: list[float]) -> dict[str, float]:
    ordered = sorted(values)
    return {
        "min": round(ordered[0], 3),
        "median": round(ordered[len(ordered) // 2], 3),
        "max": round(ordered[-1], 3),
    }


def tenant_fairness_measurement_document_errors(
    evidence: Any, recommendation: Any, baseline: Any, root: Path
) -> list[str]:
    """Validate the source-bound local fairness candidate and preserved failure."""
    prefix = "tenant-fairness measurement"
    expected_keys = {
        "schema_version",
        "status",
        "measured_on",
        "source",
        "command",
        "bindings",
        "environment",
        "candidate",
        "evaluation",
        "limits",
    }
    if not isinstance(evidence, dict) or set(evidence) != expected_keys:
        return [f"{prefix}: unexpected top-level shape"]

    errors: list[str] = []
    if (
        evidence["schema_version"] != 1
        or evidence["status"] != "phase0_local_fairness_candidate_evidence"
    ):
        errors.append(f"{prefix}: unsupported schema or status")
    try:
        date.fromisoformat(evidence["measured_on"])
    except TypeError, ValueError:
        errors.append(f"{prefix}: measured_on must be an ISO date")

    target_path = (
        root / "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json"
    )
    baseline_path = (
        root / "spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json"
    )
    bindings = evidence["bindings"]
    expected_bindings = {
        "target_recommendation_sha256",
        "failed_capacity_recovery_sha256",
        "raw_failure_disposition",
        "raw_noisy_tenant_p95_degradation_percent",
    }
    if not isinstance(bindings, dict) or set(bindings) != expected_bindings:
        errors.append(f"{prefix}: malformed evidence bindings")
    else:
        if bindings["target_recommendation_sha256"] != file_sha256(
            target_path
        ) or recommendation.get("profile") != baseline.get("envelope"):
            errors.append(f"{prefix}: target recommendation binding is stale")
        raw_evaluation = baseline.get("evaluation", {})
        raw_noisy = (
            baseline.get("capacity", {})
            .get("noisy_tenant", {})
            .get("other_tenant_p95_degradation_percent")
        )
        if (
            bindings["failed_capacity_recovery_sha256"] != file_sha256(baseline_path)
            or bindings["raw_failure_disposition"] != raw_evaluation.get("disposition")
            or bindings["raw_noisy_tenant_p95_degradation_percent"] != raw_noisy
            or raw_evaluation.get("passed") is not False
            or raw_evaluation.get("checks", {}).get("noisy_tenant_degradation") is not False
        ):
            errors.append(f"{prefix}: failed baseline binding is stale")

    expected_sources = {
        "tools/measure_phase0_tenant_fairness.py",
        "tools/measure_phase0_capacity_recovery.py",
        "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json",
        "spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json",
    }
    source = evidence["source"]
    if (
        not isinstance(source, dict)
        or set(source) != {"git_revision", "working_tree", "artifacts_sha256"}
        or not isinstance(source["git_revision"], str)
        or not re.fullmatch(r"[0-9a-f]{40}", source["git_revision"])
        or source["working_tree"] not in {"clean", "dirty"}
        or not isinstance(source["artifacts_sha256"], dict)
        or set(source["artifacts_sha256"]) != expected_sources
    ):
        errors.append(f"{prefix}: malformed source record")
    else:
        for relative_path, digest in source["artifacts_sha256"].items():
            if (
                not isinstance(digest, str)
                or not SHA256_PATTERN.fullmatch(digest)
                or not (root / relative_path).is_file()
                or file_sha256(root / relative_path) != digest
            ):
                errors.append(f"{prefix}: measured source drifted: {relative_path}")

    if not isinstance(evidence["command"], str) or not all(
        fragment in evidence["command"]
        for fragment in ("measure_phase0_tenant_fairness.py", "--repetitions 3")
    ):
        errors.append(f"{prefix}: exact measurement command is missing")

    environment = evidence["environment"]
    if (
        not isinstance(environment, dict)
        or environment.get("postgresql_version") != "18.6 (Homebrew)"
        or environment.get("postgresql_settings", {}).get("fsync") != "on"
        or environment.get("postgresql_settings", {}).get("synchronous_commit") != "on"
        or environment.get("postgresql_settings", {}).get("wal_level") != "replica"
        or environment.get("topology")
        != "local disposable pooled primary; database-transaction admission proxy"
    ):
        errors.append(f"{prefix}: environment or durability settings are incomplete")

    candidate = evidence["candidate"]
    expected_candidate_keys = {
        "name",
        "admission_layer",
        "slots_per_tenant",
        "bounded_retry_delay_ms",
        "rejection_result",
        "runs",
        "summary",
    }
    if (
        not isinstance(candidate, dict)
        or set(candidate) != expected_candidate_keys
        or candidate.get("name") != "two_slots_per_tenant_database_advisory_lock_proxy"
        or candidate.get("admission_layer") != "database_transaction_proxy_only"
        or candidate.get("slots_per_tenant") != 2
        or candidate.get("bounded_retry_delay_ms") != 20
        or candidate.get("rejection_result") != -1
    ):
        errors.append(f"{prefix}: malformed bounded candidate")
        runs: Any = None
    else:
        runs = candidate["runs"]

    degradations: list[float] = []
    noisy_rejections: list[float] = []
    other_rejections: list[float] = []
    other_p95_values: list[float] = []
    expected_attempts = {"1": 800, "2": 100, "3": 100, "4": 100, "5": 100}
    if not isinstance(runs, list) or len(runs) != 3:
        errors.append(f"{prefix}: expected three fairness repetitions")
    else:
        for repetition, run_item in enumerate(runs, start=1):
            baseline_other = (
                run_item.get("baseline_other_tenants", {}) if isinstance(run_item, dict) else {}
            )
            under_noise = (
                run_item.get("candidate_under_noise", {}) if isinstance(run_item, dict) else {}
            )
            counts = under_noise.get("counts_by_tenant", {})
            admitted = under_noise.get("admitted_batches_by_tenant", {})
            rejected = under_noise.get("rejected_attempts_by_tenant", {})
            assertions = under_noise.get("assertions", {})
            baseline_p95 = baseline_other.get("latency_ms", {}).get("p95", 0)
            during_p95 = under_noise.get("other_tenants", {}).get("latency_ms", {}).get("p95", 0)
            degradation = run_item.get("other_tenant_p95_degradation_percent")
            counts_are_atomic = (
                isinstance(counts, dict)
                and set(counts) == set(expected_attempts)
                and all(
                    isinstance(counts[tenant], dict)
                    and counts[tenant].get("batches") == admitted.get(tenant)
                    and counts[tenant].get("facts") == admitted.get(tenant, -1) * 25
                    and counts[tenant].get("audit_events") == admitted.get(tenant)
                    and counts[tenant].get("outbox_events") == admitted.get(tenant)
                    for tenant in expected_attempts
                )
            )
            baseline_counts = baseline_other.get("counts_by_tenant", {})
            expected_baseline_counts = {
                "1": {"batches": 0, "facts": 0, "audit_events": 0, "outbox_events": 0},
                **{
                    str(tenant): {
                        "batches": 100,
                        "facts": 2500,
                        "audit_events": 100,
                        "outbox_events": 100,
                    }
                    for tenant in range(2, 6)
                },
            }
            run_valid = (
                isinstance(run_item, dict)
                and run_item.get("repetition") == repetition
                and baseline_other.get("transactions") == 400
                and baseline_counts == expected_baseline_counts
                and under_noise.get("attempts_by_tenant") == expected_attempts
                and isinstance(admitted, dict)
                and set(admitted) == set(expected_attempts)
                and isinstance(rejected, dict)
                and rejected.get("1", 0) > 0
                and all(rejected.get(str(tenant)) == 0 for tenant in range(2, 6))
                and all(
                    admitted.get(tenant, -1) + rejected.get(tenant, -1) == attempts
                    for tenant, attempts in expected_attempts.items()
                )
                and counts_are_atomic
                and isinstance(assertions, dict)
                and assertions
                and all(value is True for value in assertions.values())
                and isinstance(baseline_p95, (int, float))
                and baseline_p95 > 0
                and isinstance(during_p95, (int, float))
                and during_p95 > 0
                and isinstance(degradation, (int, float))
                and round((during_p95 - baseline_p95) / baseline_p95 * 100, 3) == degradation
            )
            if not run_valid:
                errors.append(f"{prefix}: fairness repetition {repetition} is incomplete")
                continue
            degradations.append(float(degradation))
            noisy_rejections.append(float(rejected["1"]))
            other_rejections.append(float(sum(rejected[str(tenant)] for tenant in range(2, 6))))
            other_p95_values.append(float(during_p95))

    summary = candidate.get("summary", {}) if isinstance(candidate, dict) else {}
    expected_summary_keys = {
        "other_tenant_p95_degradation_percent",
        "noisy_tenant_rejected_attempts",
        "other_tenant_rejected_attempts",
        "other_tenant_p95_ms_under_noise",
        "all_safety_assertions_passed",
    }
    if len(degradations) == 3:
        expected_summary = {
            "other_tenant_p95_degradation_percent": _measurement_distribution(degradations),
            "noisy_tenant_rejected_attempts": _measurement_distribution(noisy_rejections),
            "other_tenant_rejected_attempts": _measurement_distribution(other_rejections),
            "other_tenant_p95_ms_under_noise": _measurement_distribution(other_p95_values),
            "all_safety_assertions_passed": True,
        }
        if (
            not isinstance(summary, dict)
            or set(summary) != expected_summary_keys
            or summary != expected_summary
        ):
            errors.append(f"{prefix}: fairness summary does not match repeated runs")

    placement_limit = next(
        (
            target.get("metrics", {}).get("other_tenant_p95_degradation_percent_max")
            for target in recommendation.get("targets", [])
            if target.get("id") == "tenant_placement"
        ),
        None,
    )
    evaluation = evidence["evaluation"]
    expected_check_keys = {
        "raw_failed_baseline_preserved",
        "candidate_other_tenant_degradation",
        "candidate_other_tenants_not_rejected",
        "candidate_noisy_tenant_backpressured",
        "candidate_batch_latency",
        "candidate_safety_contract",
    }
    checks = evaluation.get("checks", {}) if isinstance(evaluation, dict) else {}
    if (
        evaluation.get("passed") is not True
        or evaluation.get("disposition")
        != "local_fairness_candidate_passed_managed_confirmation_required"
        or not isinstance(checks, dict)
        or set(checks) != expected_check_keys
        or any(value is not True for value in checks.values())
        or not isinstance(placement_limit, (int, float))
        or summary.get("other_tenant_p95_degradation_percent", {}).get("max", 10**9)
        > placement_limit
    ):
        errors.append(f"{prefix}: candidate evaluation must preserve the passing local result")
    if (
        not isinstance(evidence["limits"], list)
        or len(evidence["limits"]) < 5
        or any(not isinstance(limit, str) or not limit.strip() for limit in evidence["limits"])
        or not any("before database pool checkout" in limit for limit in evidence["limits"])
    ):
        errors.append(f"{prefix}: measurement limits are incomplete")
    return errors


def tenant_fairness_measurement_errors(root: Path) -> list[str]:
    evidence_path = (
        root / "spikes/ash-foundation-lab/priv/maintenance/tenant-fairness-measurement.json"
    )
    recommendation_path = (
        root / "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json"
    )
    baseline_path = (
        root / "spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json"
    )
    try:
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
        recommendation = json.loads(recommendation_path.read_text(encoding="utf-8"))
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"tenant-fairness measurement: cannot read artifact: {error}"]
    return tenant_fairness_measurement_document_errors(evidence, recommendation, baseline, root)


def phase0_followup_evidence_errors(
    root: Path, *, skip_clean_checkout: bool | None = None
) -> list[str]:
    """Validate accepted targets, follow-ups, and the withdrawn AWS estimate."""
    if skip_clean_checkout is None:
        skip_clean_checkout = os.environ.get("CHIMWEMWE_CLEAN_CHECKOUT_REHEARSAL") == "1"

    maintenance = root / "spikes/ash-foundation-lab/priv/maintenance"
    paths = {
        "recommendation": maintenance / "quality-target-recommendation.json",
        "approval": maintenance / "quality-target-technical-approval.json",
        "precheckout": maintenance / "precheckout-admission-measurement.json",
        "topology": maintenance / "managed-postgresql-topology.json",
        "restore": maintenance / "full-horizon-restore-measurement.json",
        "security": maintenance / "ash-security-patch.json",
    }
    try:
        documents = {
            name: json.loads(path.read_text(encoding="utf-8")) for name, path in paths.items()
        }
    except (OSError, json.JSONDecodeError) as error:
        return [f"Phase 0 follow-up evidence: cannot read artifact: {error}"]

    errors: list[str] = []
    recommendation = documents["recommendation"]
    approval = documents["approval"]
    target_ids = [target.get("id") for target in recommendation.get("targets", [])]
    if (
        approval.get("status") != "accepted_technical_planning_baseline"
        or approval.get("recommendation_sha256") != file_sha256(paths["recommendation"])
        or approval.get("accepted_without_amendment") is not True
        or approval.get("accepted_target_ids") != target_ids
        or approval.get("authority", {}).get("decision_authority") != "project_owner_instruction"
    ):
        errors.append("quality-target technical approval is stale or incomplete")

    precheckout = documents["precheckout"]
    precheckout_sources = precheckout.get("source", {}).get("artifacts_sha256", {})
    stale_precheckout_sources = [
        relative
        for relative, digest in precheckout_sources.items()
        if not (root / relative).is_file() or file_sha256(root / relative) != digest
    ]
    summary = precheckout.get("measurement", {}).get("summary", {})
    placement_limit = next(
        target["metrics"]["other_tenant_p95_degradation_percent_max"]
        for target in recommendation["targets"]
        if target["id"] == "tenant_placement"
    )
    if stale_precheckout_sources:
        errors.append("pre-checkout admission measurement has stale source bindings")
    if (
        precheckout.get("evaluation", {}).get("passed") is not True
        or precheckout.get("evaluation", {}).get("disposition")
        != "local_precheckout_candidate_passed_managed_confirmation_required"
        or summary.get("all_safety_assertions_passed") is not True
        or summary.get("other_tenant_p95_degradation_percent", {}).get("max", 10**9)
        > placement_limit
    ):
        errors.append("pre-checkout admission measurement does not preserve its passing result")

    topology = documents["topology"]
    if (
        topology.get("status") != "selected_technical_baseline_live_measurement_blocked"
        or topology.get("provider") != "Amazon Web Services"
        or topology.get("database", {}).get("deployment")
        != "Multi-AZ DB instance with one synchronous non-readable standby"
        or topology.get("execution", {}).get("managed_capacity_fairness_failover_run")
        != "blocked_no_aws_account_endpoint_or_credentials_in_workspace"
        or topology.get("execution", {}).get("secrets_recorded") is not False
    ):
        errors.append("withdrawn historical AWS topology artifact changed unexpectedly")

    topology_note = (root / "docs/phase-0/evidence/managed-postgresql-topology.md").read_text(
        encoding="utf-8"
    )
    availability_adr = (
        root
        / "docs/adr/0017-postgresql-availability-recovery-and-consistency-aware-read-routing.md"
    ).read_text(encoding="utf-8")
    if (
        "- Status: Withdrawn; provider selection deferred beyond Phase 0" not in topology_note
        or "AWS will not be used" not in topology_note
        or "- Status: Accepted" not in availability_adr
        or "provider-neutral" not in availability_adr
    ):
        errors.append("provider-neutral decision or withdrawn AWS evidence note is incomplete")

    restore = documents["restore"]
    restore_sources = restore.get("source", {}).get("artifacts_sha256", {})
    stale_restore_sources = [
        relative
        for relative, digest in restore_sources.items()
        if not (root / relative).is_file() or file_sha256(root / relative) != digest
    ]
    recovery = restore.get("recovery", {})
    if stale_restore_sources:
        errors.append("full-horizon restore measurement has stale source bindings")
    if (
        restore.get("evaluation", {}).get("passed") is not True
        or recovery.get("retained_rows") != 131_200_000
        or recovery.get("planning_horizon_fraction") != 1.0
        or recovery.get("integrity_mismatches") != 0
        or not recovery.get("assertions")
        or any(value is not True for value in recovery["assertions"].values())
    ):
        errors.append("full-horizon restore measurement does not preserve its passing result")

    security = documents["security"]
    spike_lock = root / "spikes/ash-foundation-lab/mix.lock"
    core_lock = root / "mix.lock"
    spike_versions = locked_hex_versions(root)
    core_versions = locked_hex_versions_from_path(core_lock)
    generated_artifacts = security.get("generated_artifacts", {})
    expected_generated_artifacts = {
        "openapi_sha256": root / "spikes/ash-foundation-lab/priv/openapi/phase0-v1.json",
        "typescript_schema_sha256": root
        / "spikes/ash-foundation-lab/typescript-client-review/generated/schema.d.ts",
        "resource_descriptor_sha256": root
        / "spikes/ash-foundation-lab/priv/resource_descriptors/foundation-record.v1.json",
    }
    generated_artifacts_current = all(
        path.is_file() and generated_artifacts.get(name) == file_sha256(path)
        for name, path in expected_generated_artifacts.items()
    )
    if (
        security.get("status") != "phase0_security_patch_verified"
        or security.get("advisory", {}).get("id") != "EEF-CVE-2026-93477"
        or security.get("advisory", {}).get("fixed_version") != "3.33.11"
        or security.get("previous_advisory", {}).get("id") != "EEF-CVE-2026-86338"
        or security.get("previous_advisory", {}).get("fixed_version") != "3.33.4"
        or spike_versions.get("ash") != "3.33.11"
        or core_versions.get("ash") != "3.33.11"
        or security.get("upgrade", {}).get("foundation_lab_lock_sha256") != file_sha256(spike_lock)
        or security.get("upgrade", {}).get("production_core_lock_sha256") != file_sha256(core_lock)
        or security.get("regression", {}).get("test")
        != "spikes/ash-foundation-lab/test/ash_foundation_lab/bulk_private_argument_regression_test.exs"
        or security.get("regression", {}).get("result") != "pass"
        or not generated_artifacts_current
        or generated_artifacts.get("openapi_removed_filter_properties")
        != ["range_adjacent", "range_contains", "range_overlaps"]
        or generated_artifacts.get("openapi_added_filter_properties") != []
        or generated_artifacts.get("public_paths_changed") is not False
        or security.get("verification", {}).get("make_check") != "pass"
    ):
        errors.append("Ash security-patch evidence is stale or incomplete")

    clean_path = maintenance / "clean-checkout-rehearsal.json"
    if clean_path.exists() and not skip_clean_checkout:
        try:
            clean = json.loads(clean_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            errors.append(f"clean-checkout rehearsal cannot be read: {error}")
        else:
            source_hashes = clean.get("source_sha256", {})
            stale_sources = [
                relative
                for relative, digest in source_hashes.items()
                if not (root / relative).is_file() or file_sha256(root / relative) != digest
            ]
            if (
                clean.get("status") != "phase0_clean_checkout_rehearsal_passed"
                or clean.get("candidate", {}).get("clean_before_bootstrap") is not True
                or clean.get("bootstrap", {}).get("exit_code") != 0
                or clean.get("bootstrap", {}).get("clean_after") is not True
                or clean.get("verification", {}).get("exit_code") != 0
                or clean.get("verification", {}).get("clean_after") is not True
                or stale_sources
            ):
                errors.append("clean-checkout rehearsal is stale or did not preserve a clean pass")
    return errors


def locked_hex_versions_from_path(lock_path: Path) -> dict[str, str]:
    """Return Hex versions from a specific Mix lock."""
    pattern = re.compile(
        r'^\s*"(?P<name>[a-z0-9_]+)": \{:hex, :[a-z0-9_]+, "(?P<version>[^"]+)"',
        re.MULTILINE,
    )
    return {
        match.group("name"): match.group("version")
        for match in pattern.finditer(lock_path.read_text(encoding="utf-8"))
    }


def validate_repository(root: Path, *, exit_review: bool = False) -> list[str]:
    """Validate the repository contract and return all discovered errors."""
    errors: list[str] = []

    for relative_path in REQUIRED_PATHS:
        if not (root / relative_path).exists():
            errors.append(f"missing required path: {relative_path}")

    errors.extend(phase_boundary_errors(root))

    for path in sorted(root.rglob("*.md")):
        if any(part in IGNORED_DIRECTORY_NAMES for part in path.parts):
            continue
        errors.extend(markdown_errors(path, root))

    if (root / "docs/adr/README.md").exists():
        errors.extend(adr_errors(root))
    if (root / "docs/security/threat-model.md").exists():
        errors.extend(threat_model_errors(root))
    if (root / "spikes/ash-foundation-lab/priv/maintenance/ash-nonpatch-upgrade.json").exists():
        errors.extend(ash_upgrade_evidence_errors(root))
    bounded_condition_disposition = (
        root / "spikes/ash-foundation-lab/priv/maintenance/ash-bounded-condition-disposition.json"
    )
    if bounded_condition_disposition.exists():
        errors.extend(ash_bounded_condition_disposition_errors(root))
    quality_target_recommendation = (
        root / "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json"
    )
    if quality_target_recommendation.exists():
        errors.extend(quality_target_recommendation_errors(root))
    capacity_recovery_measurement = (
        root / "spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json"
    )
    if capacity_recovery_measurement.exists():
        errors.extend(capacity_recovery_measurement_errors(root))
    tenant_fairness_measurement = (
        root / "spikes/ash-foundation-lab/priv/maintenance/tenant-fairness-measurement.json"
    )
    if tenant_fairness_measurement.exists():
        errors.extend(tenant_fairness_measurement_errors(root))
    errors.extend(
        phase0_followup_evidence_errors(
            root,
            skip_clean_checkout=os.environ.get("CHIMWEMWE_CLEAN_CHECKOUT_REHEARSAL") == "1",
        )
    )
    retained_data_measurement = (
        root / "spikes/ash-foundation-lab/priv/maintenance/retained-data-migration-measurement.json"
    )
    if retained_data_measurement.exists():
        errors.extend(retained_data_measurement_evidence_errors(root))
    if exit_review:
        errors.extend(exit_review_errors(root))

    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--exit-review",
        action="store_true",
        help="also reject unresolved owners, targets, dates, and Proposed ADRs",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = repository_root()
    errors = validate_repository(root, exit_review=args.exit_review)

    if errors:
        print("Phase 0 repository validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    mode = "exit-review" if args.exit_review else "working"
    print(f"Phase 0 repository validation passed ({mode} mode).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
