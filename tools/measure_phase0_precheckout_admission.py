"""Measure Elixir tenant admission before Ecto/Postgrex pool checkout."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import subprocess
import tempfile
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import measure_phase0_capacity_recovery as capacity

ROOT = Path(__file__).resolve().parents[1]
LAB = ROOT / "spikes/ash-foundation-lab"
TARGET_PATH = LAB / "priv/maintenance/quality-target-recommendation.json"
FAILED_BASELINE_PATH = LAB / "priv/maintenance/capacity-recovery-measurement.json"
DATABASE_PROXY_PATH = LAB / "priv/maintenance/tenant-fairness-measurement.json"
DEFAULT_OUTPUT = LAB / "priv/maintenance/precheckout-admission-measurement.json"
SOURCE_PATHS = [
    ROOT / "tools/measure_phase0_precheckout_admission.py",
    LAB / "lib/ash_foundation_lab/tenant_admission.ex",
    LAB / "lib/mix/tasks/phase0.tenant_admission.measure.ex",
    TARGET_PATH,
    FAILED_BASELINE_PATH,
    DATABASE_PROXY_PATH,
]


def file_sha256(path: Path) -> str:
    """Return the SHA-256 digest of one evidence input."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_record() -> dict[str, Any]:
    """Bind the result to code, targets, and both earlier fairness artifacts."""
    revision = capacity.run(["git", "rev-parse", "HEAD"]).stdout.strip()
    dirty = capacity.run(["git", "status", "--porcelain"]).stdout.strip()
    return {
        "git_revision": revision,
        "working_tree": "dirty" if dirty else "clean",
        "artifacts_sha256": {
            str(path.relative_to(ROOT)): file_sha256(path) for path in SOURCE_PATHS
        },
    }


def environment_record(primary: capacity.Cluster) -> dict[str, Any]:
    """Record the local host and PostgreSQL pool boundary under test."""
    return {
        "operating_system": platform.platform(),
        "architecture": platform.machine(),
        "postgresql_version": capacity.scalar(primary, "SHOW server_version;", database="postgres"),
        "topology": "fresh local PostgreSQL primary with a ten-connection Ecto sandbox pool",
        "managed_service": False,
        "application_nodes": 1,
        "ecto_pool_size": 10,
    }


def run_elixir_measurement(primary: capacity.Cluster, repetitions: int) -> dict[str, Any]:
    """Run the source-controlled Elixir candidate against the disposable cluster."""
    env = os.environ.copy()
    env.update(
        {
            "MIX_ENV": "test",
            "PGHOST": str(primary.socket_dir),
            "PGPORT": str(primary.port),
            "PGDATABASE": capacity.DATABASE,
            "PGUSER": capacity.APP_USER,
            "PGPASSWORD": "",
            "PHASE0_ADMISSION_REPETITIONS": str(repetitions),
        }
    )
    completed = subprocess.run(
        ["mise", "exec", "--", "mix", "phase0.tenant_admission.measure"],
        check=False,
        capture_output=True,
        cwd=LAB,
        env=env,
        text=True,
    )
    if completed.returncode != 0:
        raise capacity.MeasurementError("Elixir admission task failed: " + completed.stderr.strip())
    marker = "PHASE0_ADMISSION_RESULT="
    for line in completed.stdout.splitlines():
        if line.startswith(marker):
            return json.loads(line.removeprefix(marker))
    raise capacity.MeasurementError("Elixir admission task did not emit its JSON result")


def target_metrics(targets: dict[str, Any], target_id: str) -> dict[str, Any]:
    """Return metrics for one target row."""
    for target in targets["targets"]:
        if target["id"] == target_id:
            return target["metrics"]
    raise capacity.MeasurementError(f"missing target: {target_id}")


def evaluate(
    result: dict[str, Any],
    targets: dict[str, Any],
    failed_baseline: dict[str, Any],
    database_proxy: dict[str, Any],
) -> dict[str, Any]:
    """Evaluate pre-checkout behaviour without erasing either prior result."""
    placement = target_metrics(targets, "tenant_placement")
    runs = result["runs"]
    checks = {
        "raw_failed_baseline_preserved": (
            failed_baseline["evaluation"]["passed"] is False
            and failed_baseline["evaluation"]["checks"]["noisy_tenant_degradation"] is False
        ),
        "database_proxy_followup_preserved": database_proxy["evaluation"]["passed"] is True,
        "admission_precedes_repository_callback": all(
            run["candidate"]["rejected_callbacks_invoked"] == 0
            and run["safety"]["rejected_before_database_callback"]
            for run in runs
        ),
        "other_tenant_degradation": (
            result["summary"]["other_tenant_p95_degradation_percent"]["max"]
            <= placement["other_tenant_p95_degradation_percent_max"]
        ),
        "other_tenants_not_rejected": all(
            run["safety"]["other_tenants_not_rejected"] for run in runs
        ),
        "noisy_tenant_backpressured": all(
            run["safety"]["noisy_tenant_backpressured"] for run in runs
        ),
        "placement_budget_preserved": all(run["safety"]["placement_not_exhausted"] for run in runs),
        "atomicity_audit_and_outbox_preserved": all(
            run["safety"]["all_admitted_batches_atomic"] for run in runs
        ),
    }
    passed = all(checks.values())
    return {
        "checks": checks,
        "passed": passed,
        "disposition": (
            "local_precheckout_candidate_passed_managed_confirmation_required"
            if passed
            else "local_precheckout_candidate_has_failed_gate"
        ),
    }


def measure(repetitions: int) -> dict[str, Any]:
    """Create a fresh database and run the pre-checkout measurement."""
    targets = json.loads(TARGET_PATH.read_text(encoding="utf-8"))
    failed_baseline = json.loads(FAILED_BASELINE_PATH.read_text(encoding="utf-8"))
    database_proxy = json.loads(DATABASE_PROXY_PATH.read_text(encoding="utf-8"))

    with tempfile.TemporaryDirectory(prefix="chim-phase0-precheckout-", dir="/tmp") as temporary:
        base = Path(temporary)
        archive_dir = base / "archive"
        archive_dir.mkdir()
        primary = capacity.init_cluster(base, "primary", capacity.free_port(), archive_dir)
        try:
            capacity.start_cluster(primary)
            capacity.setup_database(primary)
            environment = environment_record(primary)
            print("pre-checkout admission: running three fairness comparisons", flush=True)
            measurement = run_elixir_measurement(primary, repetitions)
            evaluation = evaluate(measurement, targets, failed_baseline, database_proxy)
            return {
                "schema_version": 1,
                "status": "phase0_local_precheckout_admission_evidence",
                "measured_on": datetime.now(UTC).date().isoformat(),
                "source": source_record(),
                "command": (
                    "mise exec -- uv run python tools/measure_phase0_precheckout_admission.py "
                    "--repetitions 3 --output spikes/ash-foundation-lab/priv/maintenance/"
                    "precheckout-admission-measurement.json"
                ),
                "bindings": {
                    "target_recommendation_sha256": file_sha256(TARGET_PATH),
                    "failed_capacity_recovery_sha256": file_sha256(FAILED_BASELINE_PATH),
                    "database_proxy_fairness_sha256": file_sha256(DATABASE_PROXY_PATH),
                },
                "environment": environment,
                "measurement": measurement,
                "evaluation": evaluation,
                "limits": [
                    "This is disposable Phase 0 evidence, not a production admission API.",
                    "The callback boundary proves rejected work cannot call Ecto or request a Postgrex connection; it does not replace Ash policy or action authorization.",
                    "The local single-node pool does not reproduce managed-service network latency, provider maintenance, DNS failover, or multi-node distributed admission.",
                    "The two-per-tenant and ten-per-placement limits are the accepted planning baseline and must be recalibrated from managed measurements before production.",
                ],
            }
        finally:
            capacity.stop_cluster(primary)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.repetitions < 1:
        raise SystemExit("repetitions must be positive")
    result = measure(args.repetitions)
    output = args.output if args.output.is_absolute() else ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {output}", flush=True)
    print(result["evaluation"]["disposition"], flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
