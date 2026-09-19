"""Measure a full 131.2-million-row local PostgreSQL PITR rehearsal."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import measure_phase0_capacity_recovery as capacity

ROOT = Path(__file__).resolve().parents[1]
LAB = ROOT / "spikes/ash-foundation-lab"
TARGET_PATH = LAB / "priv/maintenance/quality-target-recommendation.json"
APPROVAL_PATH = LAB / "priv/maintenance/quality-target-technical-approval.json"
TOPOLOGY_PATH = LAB / "priv/maintenance/managed-postgresql-topology.json"
DEFAULT_OUTPUT = LAB / "priv/maintenance/full-horizon-restore-measurement.json"
PLANNING_HORIZON_ROWS = 131_200_000
LOAD_CHUNK_ROWS = 10_000_000


def file_sha256(path: Path) -> str:
    """Return a SHA-256 digest."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_full_horizon(primary: capacity.Cluster, retained_rows: int) -> dict[str, Any]:
    """Load deterministic synthetic rows in reviewable progress chunks."""
    capacity.psql(
        primary,
        "TRUNCATE phase0_recovery_payload, phase0_recovery_markers RESTART IDENTITY;",
    )
    started = time.perf_counter()
    for first in range(1, retained_rows + 1, LOAD_CHUNK_ROWS):
        last = min(first + LOAD_CHUNK_ROWS - 1, retained_rows)
        chunk_started = time.perf_counter()
        capacity.psql(
            primary,
            "INSERT INTO phase0_recovery_payload (tenant_id, payload) "
            f"SELECT 1 + (value % 5), md5(value::text) "
            f"FROM generate_series({first}, {last}) value;",
        )
        elapsed = time.perf_counter() - chunk_started
        print(
            f"full-horizon: loaded {last:,}/{retained_rows:,} rows "
            f"({last - first + 1:,} in {elapsed:.1f}s)",
            flush=True,
        )
    total_seconds = time.perf_counter() - started
    return {
        "rows": retained_rows,
        "load_ms": round(total_seconds * 1000, 3),
        "rows_per_second": round(retained_rows / total_seconds, 3),
    }


def fingerprint(cluster: capacity.Cluster) -> dict[str, int]:
    """Compute a scalable, order-independent full-table integrity fingerprint."""
    print("full-horizon: scanning complete retained-data fingerprint", flush=True)
    values = capacity.scalar(
        cluster,
        "SELECT count(*), min(id), max(id), sum(id)::numeric, sum(tenant_id)::numeric, "
        "sum(hashtextextended(payload, 914287)::numeric) "
        "FROM phase0_recovery_payload;",
    ).split("|")
    keys = ["row_count", "minimum_id", "maximum_id", "id_sum", "tenant_sum", "payload_hash_sum"]
    return {key: int(value) for key, value in zip(keys, values, strict=True)}


def relation_sizes(primary: capacity.Cluster) -> dict[str, int]:
    """Record the heap, indexes, and total bytes for the planning table."""
    values = capacity.scalar(
        primary,
        "SELECT pg_relation_size('phase0_recovery_payload'), "
        "pg_indexes_size('phase0_recovery_payload'), "
        "pg_total_relation_size('phase0_recovery_payload');",
    ).split("|")
    return {
        "heap_bytes": int(values[0]),
        "index_bytes": int(values[1]),
        "total_bytes": int(values[2]),
    }


def enable_wal_archive(primary: capacity.Cluster, archive_dir: Path) -> None:
    """Enable real archiving only after the large base snapshot is established."""
    archive_command = f"test ! -f {archive_dir}/%f && cp %p {archive_dir}/%f"
    quoted = archive_command.replace("'", "''")
    capacity.psql(
        primary,
        f"ALTER SYSTEM SET archive_command = '{quoted}';",
        database="postgres",
    )
    capacity.psql(primary, "SELECT pg_reload_conf();", database="postgres")
    capacity.wait_until(
        lambda: (
            capacity.scalar(primary, "SHOW archive_command;", database="postgres")
            == archive_command
        ),
        10,
        "archive_command reload",
    )


def create_restore(
    base: Path,
    primary: capacity.Cluster,
    archive_dir: Path,
    retained_rows: int,
) -> tuple[dict[str, Any], capacity.Cluster]:
    """Create a base backup, target WAL, and isolated PITR restore."""
    load = load_full_horizon(primary, retained_rows)
    source_fingerprint = fingerprint(primary)
    sizes = relation_sizes(primary)

    base_backup = base / "full-horizon-base"
    print("full-horizon: creating streaming base backup", flush=True)
    backup_started = time.perf_counter()
    capacity.run(
        [
            capacity.command_path("pg_basebackup"),
            "-h",
            "127.0.0.1",
            "-p",
            str(primary.port),
            "-U",
            os.environ.get("USER", "postgres"),
            "-D",
            str(base_backup),
            "-X",
            "stream",
            "--checkpoint=fast",
        ]
    )
    backup_ms = (time.perf_counter() - backup_started) * 1000

    enable_wal_archive(primary, archive_dir)
    target_recorded_at = datetime.now(UTC)
    capacity.psql(primary, "INSERT INTO phase0_recovery_markers (name) VALUES ('target');")
    target_lsn = capacity.lsn(primary)
    capacity.psql(primary, "SELECT pg_switch_wal();")
    capacity.psql(primary, "INSERT INTO phase0_recovery_markers (name) VALUES ('after_target');")
    capacity.psql(primary, "SELECT pg_switch_wal();")
    archive_seconds = capacity.wait_until(
        lambda: len(list(archive_dir.glob("[0-9A-F]" * 24))) >= 2,
        60,
        "target WAL archive",
    )

    restore_dir = base / "full-horizon-restore"
    print("full-horizon: materializing isolated restore", flush=True)
    restore_started = time.perf_counter()
    shutil.copytree(base_backup, restore_dir)
    materialized_ms = (time.perf_counter() - restore_started) * 1000
    restore = capacity.Cluster(
        restore_dir,
        primary.socket_dir,
        capacity.free_port(),
        base / "full-horizon-restore.log",
    )
    capacity.append_config(
        restore.data_dir / "postgresql.conf",
        {
            "port": restore.port,
            "unix_socket_directories": capacity.sql_literal(restore.socket_dir),
            "archive_mode": "off",
            "restore_command": capacity.sql_literal(f"cp {archive_dir}/%f %p"),
            "recovery_target_lsn": capacity.sql_literal(target_lsn),
            "recovery_target_inclusive": "on",
            "recovery_target_action": "promote",
        },
    )
    (restore.data_dir / "recovery.signal").touch()
    startup_started = time.perf_counter()
    capacity.start_cluster(restore)
    startup_ms = (time.perf_counter() - startup_started) * 1000
    restore_rto_ms = (time.perf_counter() - restore_started) * 1000

    marker_count = int(
        capacity.scalar(
            restore,
            "SELECT count(*) FROM phase0_recovery_markers WHERE name = 'target';",
        )
    )
    after_target_count = int(
        capacity.scalar(
            restore,
            "SELECT count(*) FROM phase0_recovery_markers WHERE name = 'after_target';",
        )
    )
    restored_fingerprint = fingerprint(restore)
    restore_sizes = relation_sizes(restore)
    integrity_mismatches = 0 if restored_fingerprint == source_fingerprint else 1
    recovery_target = next(
        target["metrics"]
        for target in json.loads(TARGET_PATH.read_text(encoding="utf-8"))["targets"]
        if target["id"] == "database_recovery"
    )
    assertions = {
        "full_planning_horizon_loaded": retained_rows == PLANNING_HORIZON_ROWS,
        "target_marker_present": marker_count == 1,
        "after_target_marker_absent": after_target_count == 0,
        "complete_fingerprint_matches": restored_fingerprint == source_fingerprint,
        "heap_and_index_sizes_match": (
            restore_sizes["heap_bytes"] == sizes["heap_bytes"]
            and restore_sizes["index_bytes"] == sizes["index_bytes"]
        ),
        "isolated_port": restore.port != primary.port,
        "restore_rto_within_target": restore_rto_ms
        <= recovery_target["pitr_rto_seconds_max"] * 1000,
        "integrity_mismatches_within_target": integrity_mismatches
        <= recovery_target["integrity_mismatches_max"],
    }
    result = {
        "retained_rows": retained_rows,
        "planning_horizon_rows": PLANNING_HORIZON_ROWS,
        "planning_horizon_fraction": round(retained_rows / PLANNING_HORIZON_ROWS, 6),
        "load": load,
        "source_relation": sizes,
        "source_fingerprint": source_fingerprint,
        "base_backup_ms": round(backup_ms, 3),
        "base_backup_bytes": capacity.directory_size(base_backup),
        "target_lsn": target_lsn,
        "target_recorded_at": target_recorded_at.isoformat(),
        "wal_archive_availability_ms": round(archive_seconds * 1000, 3),
        "restore_materialization_ms": round(materialized_ms, 3),
        "restore_startup_and_replay_ms": round(startup_ms, 3),
        "restore_rto_ms": round(restore_rto_ms, 3),
        "restored_relation": restore_sizes,
        "restored_fingerprint": restored_fingerprint,
        "integrity_mismatches": integrity_mismatches,
        "assertions": assertions,
    }
    if not all(assertions.values()):
        raise capacity.MeasurementError(f"full-horizon restore assertion failed: {result}")
    return result, restore


def source_record() -> dict[str, Any]:
    """Bind the result to its runner, target approval, topology, and shared harness."""
    paths = [
        ROOT / "tools/measure_phase0_full_horizon_restore.py",
        ROOT / "tools/measure_phase0_capacity_recovery.py",
        TARGET_PATH,
        APPROVAL_PATH,
        TOPOLOGY_PATH,
    ]
    return {
        "git_revision": capacity.run(["git", "rev-parse", "HEAD"]).stdout.strip(),
        "working_tree": (
            "dirty" if capacity.run(["git", "status", "--porcelain"]).stdout.strip() else "clean"
        ),
        "artifacts_sha256": {str(path.relative_to(ROOT)): file_sha256(path) for path in paths},
    }


def measure(retained_rows: int) -> dict[str, Any]:
    """Run the full-horizon exercise in fresh local clusters."""
    with tempfile.TemporaryDirectory(prefix="chim-phase0-full-horizon-", dir="/tmp") as temporary:
        base = Path(temporary)
        archive_dir = base / "archive"
        archive_dir.mkdir()
        primary = capacity.init_cluster(base, "primary", capacity.free_port(), archive_dir)
        restore: capacity.Cluster | None = None
        capacity.append_config(
            primary.data_dir / "postgresql.conf", {"archive_command": "'/usr/bin/true'"}
        )
        try:
            capacity.start_cluster(primary)
            capacity.setup_database(primary)
            result, restore = create_restore(base, primary, archive_dir, retained_rows)
            return {
                "schema_version": 1,
                "status": "phase0_local_full_horizon_restore_evidence",
                "measured_on": datetime.now(UTC).date().isoformat(),
                "source": source_record(),
                "command": (
                    "mise exec -- uv run python tools/measure_phase0_full_horizon_restore.py "
                    "--retained-rows 131200000 --output spikes/ash-foundation-lab/priv/maintenance/"
                    "full-horizon-restore-measurement.json"
                ),
                "environment": capacity.environment_record(primary),
                "recovery": result,
                "evaluation": {
                    "passed": all(result["assertions"].values()),
                    "disposition": "local_full_horizon_restore_passed_managed_restore_required",
                },
                "limits": [
                    "This is a full-row-count local rehearsal on Apple Silicon, not a managed RDS restore measurement.",
                    "Synthetic row width and index shape cover the accepted attendance-fact count but do not predict every future domain, audit, correction, or attachment byte.",
                    "The WAL archive, base backup, and restore share one physical host; they validate PostgreSQL choreography and integrity, not zone or regional independence.",
                    "The local restore RTO excludes provider control-plane queueing, network transfer, lazy block initialization, DNS, and service reconfiguration.",
                ],
            }
        finally:
            if restore is not None:
                capacity.stop_cluster(restore)
            capacity.stop_cluster(primary)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--retained-rows", type=int, default=PLANNING_HORIZON_ROWS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.retained_rows != PLANNING_HORIZON_ROWS:
        raise SystemExit(
            f"retained-rows must equal the accepted full horizon: {PLANNING_HORIZON_ROWS}"
        )
    result = measure(args.retained_rows)
    output = args.output if args.output.is_absolute() else ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {output}", flush=True)
    print(result["evaluation"]["disposition"], flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
