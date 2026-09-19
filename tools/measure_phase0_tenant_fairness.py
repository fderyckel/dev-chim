"""Measure a bounded per-tenant admission candidate against the failed pooled baseline."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import statistics
import tempfile
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import measure_phase0_capacity_recovery as capacity

ROOT = Path(__file__).resolve().parents[1]
TARGET_PATH = ROOT / "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json"
BASELINE_PATH = (
    ROOT / "spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json"
)
DEFAULT_OUTPUT = (
    ROOT / "spikes/ash-foundation-lab/priv/maintenance/tenant-fairness-measurement.json"
)
SLOTS_PER_TENANT = 2
WORK_HOLD_MS = 20
OTHER_TENANT_ATTEMPTS = 100
NOISY_TENANT_ATTEMPTS = 800


def file_sha256(path: Path) -> str:
    """Return the SHA-256 digest of one source artifact."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_record() -> dict[str, Any]:
    """Bind the result to its runner, shared harness, target, and failed baseline."""
    sources = [
        ROOT / "tools/measure_phase0_tenant_fairness.py",
        ROOT / "tools/measure_phase0_capacity_recovery.py",
        TARGET_PATH,
        BASELINE_PATH,
    ]
    revision = capacity.run(["git", "rev-parse", "HEAD"]).stdout.strip()
    dirty = capacity.run(["git", "status", "--porcelain"]).stdout.strip()
    return {
        "git_revision": revision,
        "working_tree": "dirty" if dirty else "clean",
        "artifacts_sha256": {str(path.relative_to(ROOT)): file_sha256(path) for path in sources},
    }


def environment_record(primary: capacity.Cluster) -> dict[str, Any]:
    """Record the local machine and durability settings used by the candidate."""
    settings = capacity.scalar(
        primary,
        "SELECT name || '=' || setting FROM pg_settings WHERE name IN "
        "('archive_mode','fsync','full_page_writes','max_connections',"
        "'shared_buffers','synchronous_commit','wal_level') ORDER BY name;",
        database="postgres",
    ).splitlines()
    memory = capacity.run(["sysctl", "-n", "hw.memsize"]).stdout.strip()
    cpu = capacity.run(["sysctl", "-n", "hw.ncpu"]).stdout.strip()
    model = capacity.run(["sysctl", "-n", "hw.model"]).stdout.strip()
    return {
        "operating_system": platform.platform(),
        "architecture": platform.machine(),
        "machine_model": model,
        "cpu_count": int(cpu),
        "memory_bytes": int(memory),
        "postgresql_version": capacity.scalar(primary, "SHOW server_version;", database="postgres"),
        "postgresql_settings": dict(setting.split("=", maxsplit=1) for setting in settings),
        "topology": "local disposable pooled primary; database-transaction admission proxy",
    }


def install_fairness_candidate(primary: capacity.Cluster) -> None:
    """Install the disposable two-slot-per-tenant admission proxy."""
    capacity.psql(
        primary,
        f"""
CREATE OR REPLACE FUNCTION phase0_submit_batch_fair(
  requested_tenant integer,
  requested_key text,
  requested_size integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  admitted boolean;
BEGIN
  SELECT pg_try_advisory_xact_lock(73001, requested_tenant * 10 + 1)
    INTO admitted;

  IF NOT admitted THEN
    SELECT pg_try_advisory_xact_lock(73001, requested_tenant * 10 + 2)
      INTO admitted;
  END IF;

  IF NOT admitted THEN
    PERFORM pg_sleep({WORK_HOLD_MS / 1000});
    RETURN -1;
  END IF;

  PERFORM pg_sleep({WORK_HOLD_MS / 1000});
  RETURN phase0_submit_batch(requested_tenant, requested_key, requested_size);
END;
$$;
""",
        user=capacity.APP_USER,
    )


def fairness_workload_files(base: Path) -> dict[str, Path]:
    """Create deterministic tenant-one and tenants-two-through-five workloads."""
    scripts = base / "fairness-workloads"
    scripts.mkdir()
    definitions = {
        "tenant_one": """SELECT phase0_submit_batch_fair(
  1,
  concat('fair-noisy-', :client_id, '-', random(), '-', clock_timestamp()),
  25
);
""",
        "other_tenants": """\\set tenant 2 + :client_id
SELECT phase0_submit_batch_fair(
  :tenant,
  concat('fair-other-', :client_id, '-', random(), '-', clock_timestamp()),
  25
);
""",
    }
    paths: dict[str, Path] = {}
    for name, body in definitions.items():
        path = scripts / f"{name}.sql"
        path.write_text(body, encoding="utf-8")
        paths[name] = path
    return paths


def tenant_counts(primary: capacity.Cluster) -> dict[str, dict[str, int]]:
    """Return state, fact, audit, and outbox counts for every synthetic tenant."""
    rows = capacity.scalar(
        primary,
        "SELECT tenants.id, "
        "(SELECT count(*) FROM phase0_session_batches batches "
        " WHERE batches.tenant_id = tenants.id), "
        "(SELECT count(*) FROM phase0_attendance_facts facts "
        " WHERE facts.tenant_id = tenants.id), "
        "(SELECT count(*) FROM phase0_audit_events audit "
        " WHERE audit.tenant_id = tenants.id), "
        "(SELECT count(*) FROM phase0_outbox_events outbox "
        " WHERE outbox.tenant_id = tenants.id) "
        "FROM phase0_tenants tenants ORDER BY tenants.id;",
    ).splitlines()
    counts: dict[str, dict[str, int]] = {}
    for row in rows:
        tenant, batches, facts, audits, outbox = row.split("|")
        counts[tenant] = {
            "batches": int(batches),
            "facts": int(facts),
            "audit_events": int(audits),
            "outbox_events": int(outbox),
        }
    return counts


def safety_assertions(
    primary: capacity.Cluster,
    repetition: int,
    counts: dict[str, dict[str, int]],
    rejections: dict[str, int],
) -> dict[str, bool]:
    """Prove admission did not weaken tenant, atomicity, outbox, or retry contracts."""
    incomplete_batches = int(
        capacity.scalar(
            primary,
            "SELECT count(*) FROM phase0_session_batches batches "
            "LEFT JOIN phase0_attendance_facts facts "
            "ON facts.tenant_id = batches.tenant_id AND facts.batch_id = batches.id "
            "LEFT JOIN phase0_audit_events audit "
            "ON audit.tenant_id = batches.tenant_id AND audit.batch_id = batches.id "
            "LEFT JOIN phase0_outbox_events outbox "
            "ON outbox.tenant_id = batches.tenant_id AND outbox.batch_id = batches.id "
            "GROUP BY batches.tenant_id, batches.id "
            "HAVING count(DISTINCT facts.learner_number) <> 25 "
            "OR count(DISTINCT audit.id) <> 1 OR count(DISTINCT outbox.id) <> 1;",
        )
        or "0"
    )
    cross_tenant_rows = int(
        capacity.scalar(
            primary,
            "SELECT "
            "(SELECT count(*) FROM phase0_attendance_facts facts "
            " JOIN phase0_session_batches batches ON batches.id = facts.batch_id "
            " WHERE batches.tenant_id <> facts.tenant_id) + "
            "(SELECT count(*) FROM phase0_audit_events audit "
            " JOIN phase0_session_batches batches ON batches.id = audit.batch_id "
            " WHERE batches.tenant_id <> audit.tenant_id) + "
            "(SELECT count(*) FROM phase0_outbox_events outbox "
            " JOIN phase0_session_batches batches ON batches.id = outbox.batch_id "
            " WHERE batches.tenant_id <> outbox.tenant_id);",
        )
    )
    before_probe = capacity.workload_counts(primary)
    retry_key = f"fair-retry-probe-{repetition}"
    retry_values = (
        capacity.psql(
            primary,
            "BEGIN;"
            f"SELECT phase0_submit_batch_fair(1, '{retry_key}', 25);"
            f"SELECT phase0_submit_batch_fair(1, '{retry_key}', 25);"
            "ROLLBACK;",
            user=capacity.APP_USER,
        )
        .stdout.strip()
        .splitlines()
    )
    cross_key = f"fair-cross-tenant-probe-{repetition}"
    cross_probe = capacity.psql(
        primary,
        "BEGIN;"
        f"SELECT phase0_submit_batch_fair(1, '{cross_key}', 25);"
        "INSERT INTO phase0_attendance_facts "
        "(tenant_id, batch_id, learner_number, present) "
        "SELECT 2, id, 999, true FROM phase0_session_batches "
        f"WHERE tenant_id = 1 AND idempotency_key = '{cross_key}';"
        "COMMIT;",
        user=capacity.APP_USER,
        check=False,
    )
    cross_probe_rows = int(
        capacity.scalar(
            primary,
            f"SELECT count(*) FROM phase0_session_batches WHERE idempotency_key = '{cross_key}';",
        )
    )
    after_probe = capacity.workload_counts(primary)
    all_tenant_counts_atomic = all(
        item["facts"] == item["batches"] * 25
        and item["audit_events"] == item["batches"]
        and item["outbox_events"] == item["batches"]
        for item in counts.values()
    )
    total_attempts = NOISY_TENANT_ATTEMPTS + 4 * OTHER_TENANT_ATTEMPTS
    total_batches = sum(item["batches"] for item in counts.values())
    return {
        "all_admitted_batches_atomic": all_tenant_counts_atomic and incomplete_batches == 0,
        "one_audit_and_outbox_per_admitted_batch": all_tenant_counts_atomic,
        "no_cross_tenant_rows": cross_tenant_rows == 0,
        "cross_tenant_probe_rejected_without_partial_commit": (
            cross_probe.returncode != 0 and cross_probe_rows == 0
        ),
        "idempotent_retry_preserved": retry_values == ["25", "0"],
        "safety_probes_leave_counts_unchanged": before_probe == after_probe,
        "rejected_attempts_create_no_partial_batches": (
            total_batches == total_attempts - sum(rejections.values())
        ),
    }


def one_repetition(
    primary: capacity.Cluster,
    scripts: dict[str, Path],
    logs: Path,
    repetition: int,
) -> dict[str, Any]:
    """Compare other-tenant latency alone and under a bounded noisy tenant."""
    capacity.reset_workload(primary)
    baseline = capacity.execute_pgbench(
        primary,
        scripts["other_tenants"],
        logs / f"fair-other-baseline-{repetition}-",
        clients=4,
        transactions_per_client=OTHER_TENANT_ATTEMPTS,
    )
    baseline_counts = tenant_counts(primary)
    if baseline_counts["1"]["batches"] != 0 or any(
        baseline_counts[str(tenant)]["batches"] != OTHER_TENANT_ATTEMPTS for tenant in range(2, 6)
    ):
        raise capacity.MeasurementError(
            f"fairness baseline did not admit every other-tenant attempt: {baseline_counts}"
        )

    capacity.reset_workload(primary)
    noisy_prefix = logs / f"fair-noisy-tenant-{repetition}-"
    noisy_process, noisy_started = capacity.start_pgbench(
        primary,
        scripts["tenant_one"],
        noisy_prefix,
        clients=8,
        transactions_per_client=NOISY_TENANT_ATTEMPTS // 8,
    )
    time.sleep(0.05)
    other = capacity.execute_pgbench(
        primary,
        scripts["other_tenants"],
        logs / f"fair-other-during-noise-{repetition}-",
        clients=4,
        transactions_per_client=OTHER_TENANT_ATTEMPTS,
    )
    noisy = capacity.finish_pgbench(noisy_process, noisy_started, noisy_prefix)
    counts = tenant_counts(primary)
    attempts = {"1": NOISY_TENANT_ATTEMPTS} | {
        str(tenant): OTHER_TENANT_ATTEMPTS for tenant in range(2, 6)
    }
    rejections = {tenant: attempts[tenant] - counts[tenant]["batches"] for tenant in attempts}
    assertions = safety_assertions(primary, repetition, counts, rejections)
    if not all(assertions.values()):
        raise capacity.MeasurementError(
            f"tenant-fairness safety assertion failed in repetition {repetition}: {assertions}"
        )
    degradation = (
        (other["latency_ms"]["p95"] - baseline["latency_ms"]["p95"])
        / baseline["latency_ms"]["p95"]
        * 100
    )
    return {
        "repetition": repetition,
        "baseline_other_tenants": {
            **baseline,
            "counts_by_tenant": baseline_counts,
        },
        "candidate_under_noise": {
            "noisy_tenant": noisy,
            "other_tenants": other,
            "attempts_by_tenant": attempts,
            "admitted_batches_by_tenant": {
                tenant: item["batches"] for tenant, item in counts.items()
            },
            "rejected_attempts_by_tenant": rejections,
            "counts_by_tenant": counts,
            "assertions": assertions,
        },
        "other_tenant_p95_degradation_percent": round(degradation, 3),
    }


def distribution(values: list[float]) -> dict[str, float]:
    """Summarize repeated measurements without hiding the worst run."""
    return {
        "min": round(min(values), 3),
        "median": round(statistics.median(values), 3),
        "max": round(max(values), 3),
    }


def summarize(runs: list[dict[str, Any]]) -> dict[str, Any]:
    """Summarize degradation, admission, rejection, and latency across runs."""
    degradations = [run["other_tenant_p95_degradation_percent"] for run in runs]
    noisy_rejections = [
        run["candidate_under_noise"]["rejected_attempts_by_tenant"]["1"] for run in runs
    ]
    other_rejections = [
        sum(
            run["candidate_under_noise"]["rejected_attempts_by_tenant"][str(tenant)]
            for tenant in range(2, 6)
        )
        for run in runs
    ]
    other_p95 = [run["candidate_under_noise"]["other_tenants"]["latency_ms"]["p95"] for run in runs]
    return {
        "other_tenant_p95_degradation_percent": distribution(degradations),
        "noisy_tenant_rejected_attempts": distribution(noisy_rejections),
        "other_tenant_rejected_attempts": distribution(other_rejections),
        "other_tenant_p95_ms_under_noise": distribution(other_p95),
        "all_safety_assertions_passed": all(
            all(run["candidate_under_noise"]["assertions"].values()) for run in runs
        ),
    }


def target_metrics(targets: dict[str, Any], target_id: str) -> dict[str, Any]:
    """Return one target's metric mapping."""
    for target in targets["targets"]:
        if target["id"] == target_id:
            return target["metrics"]
    raise capacity.MeasurementError(f"target is missing: {target_id}")


def evaluate(
    targets: dict[str, Any], baseline: dict[str, Any], summary: dict[str, Any]
) -> dict[str, Any]:
    """Evaluate the candidate without changing the preserved raw failed result."""
    placement_target = target_metrics(targets, "tenant_placement")
    write_target = target_metrics(targets, "peak_domain_writes")
    raw_checks = baseline.get("evaluation", {}).get("checks", {})
    checks = {
        "raw_failed_baseline_preserved": (
            baseline.get("evaluation", {}).get("passed") is False
            and baseline.get("evaluation", {}).get("disposition")
            == "local_measurement_has_failed_target"
            and raw_checks.get("noisy_tenant_degradation") is False
        ),
        "candidate_other_tenant_degradation": (
            summary["other_tenant_p95_degradation_percent"]["max"]
            <= placement_target["other_tenant_p95_degradation_percent_max"]
        ),
        "candidate_other_tenants_not_rejected": (
            summary["other_tenant_rejected_attempts"]["max"] == 0
        ),
        "candidate_noisy_tenant_backpressured": (
            summary["noisy_tenant_rejected_attempts"]["min"] > 0
        ),
        "candidate_batch_latency": (
            summary["other_tenant_p95_ms_under_noise"]["max"]
            <= write_target["p95_session_batch_duration_ms_max"]
        ),
        "candidate_safety_contract": summary["all_safety_assertions_passed"],
    }
    passed = all(checks.values())
    return {
        "checks": checks,
        "passed": passed,
        "disposition": (
            "local_fairness_candidate_passed_managed_confirmation_required"
            if passed
            else "local_fairness_candidate_has_failed_gate"
        ),
    }


def measure(repetitions: int) -> dict[str, Any]:
    """Run the bounded fairness comparison in a fresh disposable cluster."""
    targets = json.loads(TARGET_PATH.read_text(encoding="utf-8"))
    baseline = json.loads(BASELINE_PATH.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(
        prefix="chim-phase0-tenant-fairness-", dir="/tmp"
    ) as temporary:
        base = Path(temporary)
        archive_dir = base / "archive"
        archive_dir.mkdir()
        logs = base / "pgbench-logs"
        logs.mkdir()
        scripts = fairness_workload_files(base)
        primary = capacity.init_cluster(base, "primary", capacity.free_port(), archive_dir)
        try:
            capacity.start_cluster(primary)
            capacity.setup_database(primary)
            install_fairness_candidate(primary)
            environment = environment_record(primary)
            print(
                "fairness: comparing tenants 2-5 alone and under bounded tenant-1 load",
                flush=True,
            )
            runs = [
                one_repetition(primary, scripts, logs, repetition)
                for repetition in range(1, repetitions + 1)
            ]
            summary = summarize(runs)
            evaluation = evaluate(targets, baseline, summary)
            return {
                "schema_version": 1,
                "status": "phase0_local_fairness_candidate_evidence",
                "measured_on": datetime.now(UTC).date().isoformat(),
                "source": source_record(),
                "command": (
                    "mise exec -- uv run python tools/measure_phase0_tenant_fairness.py "
                    "--repetitions 3 --output spikes/ash-foundation-lab/priv/maintenance/"
                    "tenant-fairness-measurement.json"
                ),
                "bindings": {
                    "target_recommendation_sha256": file_sha256(TARGET_PATH),
                    "failed_capacity_recovery_sha256": file_sha256(BASELINE_PATH),
                    "raw_failure_disposition": baseline["evaluation"]["disposition"],
                    "raw_noisy_tenant_p95_degradation_percent": baseline["capacity"][
                        "noisy_tenant"
                    ]["other_tenant_p95_degradation_percent"],
                },
                "environment": environment,
                "candidate": {
                    "name": "two_slots_per_tenant_database_advisory_lock_proxy",
                    "admission_layer": "database_transaction_proxy_only",
                    "slots_per_tenant": SLOTS_PER_TENANT,
                    "bounded_retry_delay_ms": WORK_HOLD_MS,
                    "rejection_result": -1,
                    "runs": runs,
                    "summary": summary,
                },
                "evaluation": evaluation,
                "limits": [
                    "This is a disposable database-transaction proxy for algorithm feasibility, not a production admission API.",
                    "Production fairness and backpressure must run before database pool checkout; this proxy still consumes a connection and starts a transaction before rejecting work.",
                    "The local primary does not reproduce an application pool, managed service tier, network, multi-node scheduler, report system, or provider failover.",
                    "The two-slot value and bounded retry delay are experiment parameters, not accepted production configuration.",
                    "The candidate preserves the raw failed measurement as a separately hashed artifact; it does not replace or rewrite that evidence.",
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
