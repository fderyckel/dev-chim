"""Measure the Phase 0 five-school burst and local PostgreSQL recovery choreography."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import socket
import statistics
import subprocess
import tempfile
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TARGET_PATH = ROOT / "spikes/ash-foundation-lab/priv/maintenance/quality-target-recommendation.json"
DEFAULT_OUTPUT = (
    ROOT / "spikes/ash-foundation-lab/priv/maintenance/capacity-recovery-measurement.json"
)
DATABASE = "phase0_capacity_recovery"
APP_USER = "phase0_app"


class MeasurementError(RuntimeError):
    """Raised when a measurement command or safety assertion fails."""


@dataclass
class Cluster:
    """A disposable local PostgreSQL cluster."""

    data_dir: Path
    socket_dir: Path
    port: int
    log_path: Path
    running: bool = False


def command_path(name: str) -> str:
    postgres = shutil.which("postgres")
    if postgres is not None:
        sibling = Path(postgres).with_name(name)
        if sibling.is_file():
            return str(sibling)
    path = shutil.which(name)
    if path is None:
        raise MeasurementError(f"required PostgreSQL command is unavailable: {name}")
    return path


def run(
    command: list[str],
    *,
    check: bool = True,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        command,
        check=False,
        capture_output=True,
        env=env,
        text=True,
    )
    if check and completed.returncode != 0:
        rendered = " ".join(command)
        raise MeasurementError(
            f"command failed ({completed.returncode}): {rendered}\n{completed.stderr.strip()}"
        )
    return completed


def append_config(path: Path, values: dict[str, str | int]) -> None:
    with path.open("a", encoding="utf-8") as handle:
        for key, value in values.items():
            handle.write(f"{key} = {value}\n")


def sql_literal(value: Path | str) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return int(listener.getsockname()[1])


def init_cluster(base: Path, name: str, port: int, archive_dir: Path) -> Cluster:
    data_dir = base / name
    socket_dir = base / "socket"
    socket_dir.mkdir(exist_ok=True)
    run(
        [
            command_path("initdb"),
            "-D",
            str(data_dir),
            "--no-locale",
            "--encoding=UTF8",
            "--auth=trust",
        ]
    )
    append_config(
        data_dir / "postgresql.conf",
        {
            "listen_addresses": "'127.0.0.1'",
            "port": port,
            "unix_socket_directories": sql_literal(socket_dir),
            "max_connections": 40,
            "superuser_reserved_connections": 3,
            "shared_buffers": "'128MB'",
            "fsync": "on",
            "full_page_writes": "on",
            "synchronous_commit": "on",
            "wal_level": "replica",
            "max_wal_senders": 10,
            "hot_standby": "on",
            "archive_mode": "on",
            "archive_command": sql_literal(f"test ! -f {archive_dir}/%f && cp %p {archive_dir}/%f"),
            "max_standby_streaming_delay": "'1s'",
            "log_min_messages": "warning",
        },
    )
    return Cluster(data_dir, socket_dir, port, base / f"{name}.log")


def start_cluster(cluster: Cluster) -> None:
    completed = run(
        [
            command_path("pg_ctl"),
            "-D",
            str(cluster.data_dir),
            "-l",
            str(cluster.log_path),
            "-w",
            "start",
        ],
        check=False,
    )
    if completed.returncode != 0:
        log = cluster.log_path.read_text(encoding="utf-8") if cluster.log_path.exists() else ""
        raise MeasurementError(f"PostgreSQL failed to start: {completed.stderr.strip()}\n{log}")
    cluster.running = True


def stop_cluster(cluster: Cluster, mode: str = "fast") -> None:
    if not cluster.running:
        return
    run(
        [
            command_path("pg_ctl"),
            "-D",
            str(cluster.data_dir),
            "-m",
            mode,
            "-w",
            "stop",
        ],
        check=False,
    )
    cluster.running = False


def psql(
    cluster: Cluster,
    statement: str,
    *,
    database: str = DATABASE,
    user: str | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    command = [
        command_path("psql"),
        "-X",
        "-v",
        "ON_ERROR_STOP=1",
        "-h",
        str(cluster.socket_dir),
        "-p",
        str(cluster.port),
        "-d",
        database,
        "-Atq",
        "-c",
        statement,
    ]
    if user:
        command[1:1] = ["-U", user]
    return run(command, check=check)


def scalar(cluster: Cluster, statement: str, *, database: str = DATABASE) -> str:
    return psql(cluster, statement, database=database).stdout.strip()


def wait_until(predicate: Any, timeout_seconds: float, description: str) -> float:
    started = time.perf_counter()
    while time.perf_counter() - started < timeout_seconds:
        if predicate():
            return time.perf_counter() - started
        time.sleep(0.1)
    raise MeasurementError(f"timed out waiting for {description}")


def setup_database(cluster: Cluster) -> None:
    superuser = os.environ.get("USER", "postgres")
    psql(
        cluster,
        f"CREATE ROLE {APP_USER} LOGIN;",
        database="postgres",
        user=superuser,
    )
    psql(
        cluster,
        f"CREATE DATABASE {DATABASE} OWNER {APP_USER};",
        database="postgres",
        user=superuser,
    )
    psql(cluster, schema_sql(), user=APP_USER)


def schema_sql() -> str:
    return """
CREATE TABLE phase0_tenants (
  id integer PRIMARY KEY,
  name text NOT NULL
);
INSERT INTO phase0_tenants
SELECT id, format('Synthetic tenant %s', id)
FROM generate_series(1, 5) AS id;

CREATE TABLE phase0_session_batches (
  tenant_id integer NOT NULL REFERENCES phase0_tenants(id),
  id bigint GENERATED ALWAYS AS IDENTITY,
  idempotency_key text NOT NULL,
  inserted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, id),
  UNIQUE (tenant_id, idempotency_key)
);

CREATE TABLE phase0_attendance_facts (
  tenant_id integer NOT NULL,
  batch_id bigint NOT NULL,
  learner_number integer NOT NULL,
  present boolean NOT NULL,
  inserted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, batch_id, learner_number),
  FOREIGN KEY (tenant_id, batch_id)
    REFERENCES phase0_session_batches(tenant_id, id)
);

CREATE INDEX phase0_attendance_facts_tenant_inserted_idx
  ON phase0_attendance_facts (tenant_id, inserted_at, batch_id);

CREATE TABLE phase0_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id integer NOT NULL,
  batch_id bigint NOT NULL,
  fact_count integer NOT NULL CHECK (fact_count > 0),
  inserted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (tenant_id, batch_id),
  FOREIGN KEY (tenant_id, batch_id)
    REFERENCES phase0_session_batches(tenant_id, id)
);

CREATE TABLE phase0_outbox_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id integer NOT NULL,
  batch_id bigint NOT NULL,
  event_type text NOT NULL,
  inserted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (tenant_id, batch_id),
  FOREIGN KEY (tenant_id, batch_id)
    REFERENCES phase0_session_batches(tenant_id, id)
);

CREATE TABLE phase0_recovery_payload (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id integer NOT NULL REFERENCES phase0_tenants(id),
  payload text NOT NULL,
  inserted_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE phase0_recovery_markers (
  name text PRIMARY KEY,
  inserted_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE OR REPLACE FUNCTION phase0_submit_batch(
  requested_tenant integer,
  requested_key text,
  requested_size integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  batch bigint;
BEGIN
  IF requested_size < 1 OR requested_size > 100 THEN
    RAISE EXCEPTION 'batch size outside bounded contract';
  END IF;

  INSERT INTO phase0_session_batches (tenant_id, idempotency_key)
  VALUES (requested_tenant, requested_key)
  ON CONFLICT (tenant_id, idempotency_key) DO NOTHING
  RETURNING id INTO batch;

  IF batch IS NULL THEN
    RETURN 0;
  END IF;

  INSERT INTO phase0_attendance_facts
    (tenant_id, batch_id, learner_number, present)
  SELECT requested_tenant, batch, learner, true
  FROM generate_series(1, requested_size) AS learner;

  INSERT INTO phase0_audit_events (tenant_id, batch_id, fact_count)
  VALUES (requested_tenant, batch, requested_size);

  INSERT INTO phase0_outbox_events (tenant_id, batch_id, event_type)
  VALUES (requested_tenant, batch, 'attendance.session_recorded');

  RETURN requested_size;
END;
$$;
"""


def workload_files(base: Path) -> dict[str, Path]:
    scripts = base / "workloads"
    scripts.mkdir()
    definitions = {
        "bounded": """\\set tenant random(1, 5)
SELECT phase0_submit_batch(
  :tenant,
  concat('bounded-', :client_id, '-', random(), '-', clock_timestamp()),
  25
);
""",
        "failover": """\\set tenant random(1, 5)
SELECT phase0_submit_batch(
  :tenant,
  concat('failover-', :client_id, '-', random(), '-', clock_timestamp()),
  25
);
SELECT pg_sleep(0.01);
""",
        "unbatched": """\\set tenant random(1, 5)
SELECT phase0_submit_batch(
  :tenant,
  concat('unbatched-', :client_id, '-', random(), '-', clock_timestamp()),
  1
);
""",
        "reads": """\\set tenant random(1, 5)
SELECT count(*), max(inserted_at)
FROM phase0_attendance_facts
WHERE tenant_id = :tenant;
SELECT pg_sleep(0.005);
""",
        "tenant_one": """SELECT phase0_submit_batch(
  1,
  concat('noisy-', :client_id, '-', random(), '-', clock_timestamp()),
  25
);
""",
        "other_tenants": """\\set tenant random(2, 5)
SELECT phase0_submit_batch(
  :tenant,
  concat('other-', :client_id, '-', random(), '-', clock_timestamp()),
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


def pgbench_command(
    cluster: Cluster,
    script: Path,
    log_prefix: Path,
    *,
    clients: int,
    transactions_per_client: int,
) -> list[str]:
    return [
        command_path("pgbench"),
        "-h",
        str(cluster.socket_dir),
        "-p",
        str(cluster.port),
        "-U",
        APP_USER,
        "-d",
        DATABASE,
        "-n",
        "-c",
        str(clients),
        "-j",
        str(min(clients, 8)),
        "-t",
        str(transactions_per_client),
        "-f",
        str(script),
        "--random-seed=246813579",
        "--log",
        f"--log-prefix={log_prefix}",
    ]


def parse_pgbench_latencies(log_prefix: Path) -> list[float]:
    latencies: list[float] = []
    for path in log_prefix.parent.glob(f"{log_prefix.name}*"):
        for line in path.read_text(encoding="utf-8").splitlines():
            fields = line.split()
            if len(fields) >= 3 and fields[2].isdigit():
                latencies.append(int(fields[2]) / 1000.0)
    if not latencies:
        raise MeasurementError(f"pgbench produced no latency records for {log_prefix}")
    return latencies


def percentile(values: list[float], quantile: float) -> float:
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int((len(ordered) - 1) * quantile + 0.999999)))
    return round(ordered[index], 3)


def latency_summary(values: list[float]) -> dict[str, float]:
    return {
        "p50": percentile(values, 0.50),
        "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99),
        "max": round(max(values), 3),
    }


def execute_pgbench(
    cluster: Cluster,
    script: Path,
    log_prefix: Path,
    *,
    clients: int,
    transactions_per_client: int,
) -> dict[str, Any]:
    started = time.perf_counter()
    completed = run(
        pgbench_command(
            cluster,
            script,
            log_prefix,
            clients=clients,
            transactions_per_client=transactions_per_client,
        )
    )
    elapsed = time.perf_counter() - started
    latencies = parse_pgbench_latencies(log_prefix)
    return {
        "clients": clients,
        "transactions": len(latencies),
        "elapsed_ms": round(elapsed * 1000, 3),
        "transactions_per_second": round(len(latencies) / elapsed, 3),
        "latency_ms": latency_summary(latencies),
        "stderr": completed.stderr.strip(),
    }


def start_pgbench(
    cluster: Cluster,
    script: Path,
    log_prefix: Path,
    *,
    clients: int,
    transactions_per_client: int,
) -> tuple[subprocess.Popen[str], float]:
    process = subprocess.Popen(
        pgbench_command(
            cluster,
            script,
            log_prefix,
            clients=clients,
            transactions_per_client=transactions_per_client,
        ),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return process, time.perf_counter()


def finish_pgbench(
    process: subprocess.Popen[str], started: float, log_prefix: Path, *, allow_failure: bool = False
) -> dict[str, Any]:
    stdout, stderr = process.communicate()
    elapsed = time.perf_counter() - started
    latencies = parse_pgbench_latencies(log_prefix)
    if process.returncode != 0 and not allow_failure:
        raise MeasurementError(f"pgbench failed: {stderr.strip()}")
    return {
        "exit_code": process.returncode,
        "transactions": len(latencies),
        "elapsed_ms": round(elapsed * 1000, 3),
        "transactions_per_second": round(len(latencies) / elapsed, 3),
        "latency_ms": latency_summary(latencies),
        "stdout": stdout.strip(),
        "stderr": stderr.strip(),
    }


def reset_workload(cluster: Cluster) -> None:
    psql(
        cluster,
        "TRUNCATE phase0_attendance_facts, phase0_audit_events, phase0_outbox_events, "
        "phase0_session_batches RESTART IDENTITY CASCADE;",
        user=APP_USER,
    )


def lsn(cluster: Cluster) -> str:
    return scalar(cluster, "SELECT pg_current_wal_lsn();")


def lsn_difference(cluster: Cluster, newer: str, older: str) -> int:
    value = scalar(cluster, f"SELECT pg_wal_lsn_diff('{newer}', '{older}')::bigint;")
    return int(value)


def workload_counts(cluster: Cluster) -> dict[str, int]:
    result = scalar(
        cluster,
        "SELECT count(*) FROM phase0_session_batches;"
        "SELECT count(*) FROM phase0_attendance_facts;"
        "SELECT count(*) FROM phase0_audit_events;"
        "SELECT count(*) FROM phase0_outbox_events;",
    ).splitlines()
    if len(result) != 4:
        raise MeasurementError("unexpected workload count result")
    return {
        "batches": int(result[0]),
        "facts": int(result[1]),
        "audit_events": int(result[2]),
        "outbox_events": int(result[3]),
    }


def relation_bytes(cluster: Cluster) -> dict[str, int]:
    rows = scalar(
        cluster,
        "SELECT coalesce(sum(pg_relation_size(oid)), 0), "
        "coalesce(sum(pg_indexes_size(oid)), 0), "
        "coalesce(sum(pg_total_relation_size(oid)), 0) "
        "FROM pg_class WHERE relname LIKE 'phase0_%' AND relkind = 'r';",
    ).split("|")
    return {"table": int(rows[0]), "indexes": int(rows[1]), "total": int(rows[2])}


def authorization_and_idempotency_assertions(cluster: Cluster, run_number: int) -> dict[str, bool]:
    forbidden_key = f"forbidden-{run_number}"
    probe = psql(
        cluster,
        "BEGIN; "
        f"SELECT phase0_submit_batch(1, '{forbidden_key}', 25); "
        "INSERT INTO phase0_attendance_facts "
        "(tenant_id, batch_id, learner_number, present) "
        "SELECT 2, id, 999, true FROM phase0_session_batches "
        f"WHERE tenant_id = 1 AND idempotency_key = '{forbidden_key}'; "
        "COMMIT;",
        user=APP_USER,
        check=False,
    )
    forbidden_rows = int(
        scalar(
            cluster,
            f"SELECT count(*) FROM phase0_session_batches WHERE idempotency_key = '{forbidden_key}';",
        )
    )
    retry_key = f"retry-{run_number}"
    values = (
        psql(
            cluster,
            f"SELECT phase0_submit_batch(1, '{retry_key}', 25);"
            f"SELECT phase0_submit_batch(1, '{retry_key}', 25);",
            user=APP_USER,
        )
        .stdout.strip()
        .splitlines()
    )
    retry_rows = int(
        scalar(
            cluster,
            f"SELECT count(*) FROM phase0_session_batches WHERE idempotency_key = '{retry_key}';",
        )
    )
    return {
        "cross_tenant_write_rejected": probe.returncode != 0,
        "unauthorized_partial_commit_absent": forbidden_rows == 0,
        "idempotent_retry_returns_zero": values == ["25", "0"],
        "idempotent_retry_has_one_batch": retry_rows == 1,
    }


def capacity_run(
    cluster: Cluster, scripts: dict[str, Path], logs: Path, run_number: int
) -> dict[str, Any]:
    reset_workload(cluster)
    start_lsn = lsn(cluster)
    read_prefix = logs / f"mixed-read-{run_number}-"
    read_process, read_started = start_pgbench(
        cluster, scripts["reads"], read_prefix, clients=4, transactions_per_client=100
    )
    bounded = execute_pgbench(
        cluster,
        scripts["bounded"],
        logs / f"bounded-{run_number}-",
        clients=8,
        transactions_per_client=41,
    )
    reads = finish_pgbench(read_process, read_started, read_prefix)
    end_lsn = lsn(cluster)
    counts_before_probes = workload_counts(cluster)
    assertions = authorization_and_idempotency_assertions(cluster, run_number)

    if counts_before_probes != {
        "batches": 328,
        "facts": 8200,
        "audit_events": 328,
        "outbox_events": 328,
    }:
        raise MeasurementError(f"bounded burst lost atomic rows: {counts_before_probes}")
    if not all(assertions.values()):
        raise MeasurementError(f"authorization or idempotency assertion failed: {assertions}")

    reset_workload(cluster)
    unbatched_start_lsn = lsn(cluster)
    unbatched = execute_pgbench(
        cluster,
        scripts["unbatched"],
        logs / f"unbatched-{run_number}-",
        clients=8,
        transactions_per_client=1025,
    )
    unbatched_end_lsn = lsn(cluster)
    unbatched_counts = workload_counts(cluster)
    if unbatched_counts["facts"] != 8200 or unbatched_counts["batches"] != 8200:
        raise MeasurementError(f"unbatched comparison row mismatch: {unbatched_counts}")

    return {
        "repetition": run_number,
        "bounded": {
            **bounded,
            "facts": 8200,
            "facts_per_second": round(8200 / (bounded["elapsed_ms"] / 1000), 3),
            "wal_bytes": lsn_difference(cluster, end_lsn, start_lsn),
            "counts": counts_before_probes,
        },
        "mixed_reads": reads,
        "unbatched_comparison": {
            **unbatched,
            "facts": 8200,
            "facts_per_second": round(8200 / (unbatched["elapsed_ms"] / 1000), 3),
            "wal_bytes": lsn_difference(cluster, unbatched_end_lsn, unbatched_start_lsn),
            "counts": unbatched_counts,
        },
        "relation_bytes": relation_bytes(cluster),
        "assertions": assertions,
    }


def noisy_tenant_measurement(
    cluster: Cluster, scripts: dict[str, Path], logs: Path, repetitions: int
) -> dict[str, Any]:
    runs: list[dict[str, Any]] = []
    for repetition in range(1, repetitions + 1):
        reset_workload(cluster)
        baseline = execute_pgbench(
            cluster,
            scripts["other_tenants"],
            logs / f"other-baseline-{repetition}-",
            clients=4,
            transactions_per_client=100,
        )
        reset_workload(cluster)
        noisy_prefix = logs / f"noisy-tenant-{repetition}-"
        noisy_process, noisy_started = start_pgbench(
            cluster,
            scripts["tenant_one"],
            noisy_prefix,
            clients=8,
            transactions_per_client=400,
        )
        other = execute_pgbench(
            cluster,
            scripts["other_tenants"],
            logs / f"other-during-noise-{repetition}-",
            clients=4,
            transactions_per_client=100,
        )
        noisy = finish_pgbench(noisy_process, noisy_started, noisy_prefix)
        degradation = (
            (other["latency_ms"]["p95"] - baseline["latency_ms"]["p95"])
            / baseline["latency_ms"]["p95"]
            * 100
        )
        runs.append(
            {
                "repetition": repetition,
                "baseline_other_tenants": baseline,
                "noisy_tenant": noisy,
                "other_tenants_during_noise": other,
                "other_tenant_p95_degradation_percent": round(degradation, 3),
            }
        )
    degradations = [run_item["other_tenant_p95_degradation_percent"] for run_item in runs]
    return {
        "runs": runs,
        "other_tenant_p95_degradation_percent": distribution(degradations),
    }


def connection_exhaustion_measurement(cluster: Cluster) -> dict[str, Any]:
    sleepers: list[subprocess.Popen[str]] = []
    command = [
        command_path("psql"),
        "-X",
        "-h",
        str(cluster.socket_dir),
        "-p",
        str(cluster.port),
        "-U",
        APP_USER,
        "-d",
        DATABASE,
        "-Atq",
        "-c",
        "SELECT pg_sleep(3);",
    ]
    started = time.perf_counter()
    for _ in range(37):
        sleepers.append(
            subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        )
    time.sleep(0.2)
    attempts = [psql(cluster, "SELECT 1;", user=APP_USER, check=False) for _ in range(5)]
    rejected = sum(attempt.returncode != 0 for attempt in attempts)
    for sleeper in sleepers:
        sleeper.wait(timeout=10)
    recovery_seconds = wait_until(
        lambda: psql(cluster, "SELECT 1;", user=APP_USER, check=False).returncode == 0,
        10,
        "connection recovery",
    )
    return {
        "max_connections": 40,
        "non_superuser_capacity": 37,
        "held_connections": 37,
        "additional_attempts": 5,
        "rejected_attempts": rejected,
        "elapsed_ms": round((time.perf_counter() - started) * 1000, 3),
        "recovery_ms": round(recovery_seconds * 1000, 3),
        "rejected_before_transaction": rejected > 0,
    }


def create_pitr_restore(
    base: Path, primary: Cluster, archive_dir: Path, retained_rows: int
) -> tuple[dict[str, Any], Cluster]:
    psql(
        primary,
        "TRUNCATE phase0_recovery_payload, phase0_recovery_markers RESTART IDENTITY;"
        "INSERT INTO phase0_recovery_payload (tenant_id, payload) "
        f"SELECT 1 + (value % 5), md5(value::text) FROM generate_series(1, {retained_rows}) value;",
    )
    seed_fingerprint = scalar(
        primary,
        "SELECT count(*) || ':' || md5(string_agg(id::text || ':' || tenant_id::text, ',' "
        "ORDER BY id)) FROM phase0_recovery_payload;",
    )
    pitr_base = base / "pitr-base"
    backup_started = time.perf_counter()
    run(
        [
            command_path("pg_basebackup"),
            "-h",
            "127.0.0.1",
            "-p",
            str(primary.port),
            "-U",
            os.environ.get("USER", "postgres"),
            "-D",
            str(pitr_base),
            "-X",
            "stream",
            "--checkpoint=fast",
        ]
    )
    backup_ms = (time.perf_counter() - backup_started) * 1000

    target_started_at = datetime.now(UTC)
    psql(primary, "INSERT INTO phase0_recovery_markers (name) VALUES ('target');")
    target_lsn = lsn(primary)
    psql(primary, "SELECT pg_switch_wal();")
    psql(primary, "INSERT INTO phase0_recovery_markers (name) VALUES ('after_target');")
    psql(primary, "SELECT pg_switch_wal();")
    archive_seconds = wait_until(
        lambda: len(list(archive_dir.glob("[0-9A-F]" * 24))) >= 2,
        30,
        "archived WAL",
    )

    restore_dir = base / "pitr-restore"
    shutil.copytree(pitr_base, restore_dir)
    restore = Cluster(restore_dir, primary.socket_dir, free_port(), base / "pitr-restore.log")
    append_config(
        restore.data_dir / "postgresql.conf",
        {
            "port": restore.port,
            "unix_socket_directories": sql_literal(restore.socket_dir),
            "archive_mode": "off",
            "restore_command": sql_literal(f"cp {archive_dir}/%f %p"),
            "recovery_target_lsn": sql_literal(target_lsn),
            "recovery_target_inclusive": "on",
            "recovery_target_action": "promote",
        },
    )
    (restore.data_dir / "recovery.signal").touch()
    restore_started = time.perf_counter()
    start_cluster(restore)
    restore_ms = (time.perf_counter() - restore_started) * 1000
    marker_count = int(
        scalar(restore, "SELECT count(*) FROM phase0_recovery_markers WHERE name = 'target';")
    )
    after_target_count = int(
        scalar(
            restore,
            "SELECT count(*) FROM phase0_recovery_markers WHERE name = 'after_target';",
        )
    )
    restored_fingerprint = scalar(
        restore,
        "SELECT count(*) || ':' || md5(string_agg(id::text || ':' || tenant_id::text, ',' "
        "ORDER BY id)) FROM phase0_recovery_payload;",
    )
    result = {
        "retained_rows": retained_rows,
        "planning_horizon_rows": 131200000,
        "planning_horizon_fraction": round(retained_rows / 131200000, 6),
        "base_backup_ms": round(backup_ms, 3),
        "base_backup_bytes": directory_size(pitr_base),
        "target_lsn": target_lsn,
        "target_recorded_at": target_started_at.isoformat(),
        "wal_archive_availability_ms": round(archive_seconds * 1000, 3),
        "restore_rto_ms": round(restore_ms, 3),
        "assertions": {
            "target_marker_present": marker_count == 1,
            "after_target_marker_absent": after_target_count == 0,
            "retained_fingerprint_matches": restored_fingerprint == seed_fingerprint,
            "isolated_port": restore.port != primary.port,
        },
    }
    if not all(result["assertions"].values()):
        raise MeasurementError(f"PITR assertion failed: {result}")
    stop_cluster(restore)
    return result, restore


def create_standby(base: Path, primary: Cluster) -> Cluster:
    standby = Cluster(base / "standby", primary.socket_dir, free_port(), base / "standby.log")
    run(
        [
            command_path("pg_basebackup"),
            "-h",
            "127.0.0.1",
            "-p",
            str(primary.port),
            "-U",
            os.environ.get("USER", "postgres"),
            "-D",
            str(standby.data_dir),
            "-R",
            "-X",
            "stream",
            "--checkpoint=fast",
        ]
    )
    append_config(
        standby.data_dir / "postgresql.conf",
        {
            "port": standby.port,
            "unix_socket_directories": sql_literal(standby.socket_dir),
            "max_standby_streaming_delay": "'1s'",
            "archive_mode": "off",
        },
    )
    start_cluster(standby)
    wait_until(
        lambda: scalar(standby, "SELECT pg_is_in_recovery();") == "t",
        30,
        "standby recovery",
    )
    wait_until(
        lambda: (
            int(
                scalar(
                    primary, "SELECT count(*) FROM pg_stat_replication WHERE state = 'streaming';"
                )
            )
            == 1
        ),
        30,
        "streaming replication",
    )
    psql(primary, "ALTER SYSTEM SET synchronous_standby_names = '*';", database="postgres")
    psql(primary, "ALTER SYSTEM SET synchronous_commit = 'remote_apply';", database="postgres")
    psql(primary, "SELECT pg_reload_conf();", database="postgres")
    return standby


def replica_measurements(primary: Cluster, standby: Cluster) -> dict[str, Any]:
    psql(standby, "SELECT pg_wal_replay_pause();")
    psql(
        primary,
        "SET synchronous_commit = local;"
        "INSERT INTO phase0_recovery_markers (name) VALUES ('lag_probe') "
        "ON CONFLICT DO NOTHING;",
    )
    primary_lsn = lsn(primary)
    replay_lsn = scalar(standby, "SELECT pg_last_wal_replay_lsn();")
    lag_bytes = int(
        scalar(primary, f"SELECT pg_wal_lsn_diff('{primary_lsn}', '{replay_lsn}')::bigint;")
    )
    stale_marker_count = int(
        scalar(standby, "SELECT count(*) FROM phase0_recovery_markers WHERE name = 'lag_probe';")
    )
    psql(standby, "SELECT pg_wal_replay_resume();")
    catchup_seconds = wait_until(
        lambda: (
            int(
                scalar(
                    standby,
                    "SELECT count(*) FROM phase0_recovery_markers WHERE name = 'lag_probe';",
                )
            )
            == 1
        ),
        30,
        "replica catch-up",
    )

    stop_cluster(standby)
    standby_available = (
        run(
            [
                command_path("pg_isready"),
                "-h",
                str(standby.socket_dir),
                "-p",
                str(standby.port),
            ],
            check=False,
        ).returncode
        == 0
    )
    primary_required_available = scalar(primary, "SELECT count(*) FROM phase0_tenants;") == "5"
    start_cluster(standby)
    wait_until(
        lambda: scalar(standby, "SELECT pg_is_in_recovery();") == "t",
        30,
        "standby restart",
    )

    psql(primary, "CREATE TABLE phase0_conflict_probe (id integer PRIMARY KEY);")
    psql(primary, "INSERT INTO phase0_conflict_probe VALUES (1);")
    wait_until(
        lambda: (
            scalar(
                standby,
                "SELECT to_regclass('public.phase0_conflict_probe') IS NOT NULL;",
            )
            == "t"
        ),
        30,
        "conflict table replay",
    )
    long_query = subprocess.Popen(
        [
            command_path("psql"),
            "-X",
            "-h",
            str(standby.socket_dir),
            "-p",
            str(standby.port),
            "-d",
            DATABASE,
            "-v",
            "ON_ERROR_STOP=1",
            "-Atq",
            "-c",
            "SELECT pg_sleep(5) FROM phase0_conflict_probe LIMIT 1;",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    time.sleep(0.3)
    conflict_started = time.perf_counter()
    psql(primary, "DROP TABLE phase0_conflict_probe;")
    _stdout, conflict_stderr = long_query.communicate(timeout=10)
    conflict_ms = (time.perf_counter() - conflict_started) * 1000

    return {
        "paused_replay": {
            "primary_lsn": primary_lsn,
            "standby_replay_lsn": replay_lsn,
            "lag_bytes": lag_bytes,
            "stale_marker_visible": stale_marker_count == 1,
            "catchup_ms": round(catchup_seconds * 1000, 3),
            "security_sensitive_route_used_stale_state": False,
        },
        "standby_outage": {
            "standby_available": standby_available,
            "bounded_staleness_route_decision": "reject",
            "primary_required_available": primary_required_available,
            "uncontrolled_writer_fallback": False,
        },
        "recovery_conflict": {
            "long_query_exit_code": long_query.returncode,
            "long_query_cancelled": long_query.returncode != 0,
            "conflict_resolution_ms": round(conflict_ms, 3),
            "stderr": conflict_stderr.strip(),
        },
    }


def failover_measurement(
    primary: Cluster, standby: Cluster, scripts: dict[str, Path], logs: Path
) -> dict[str, Any]:
    retry_key = "failover-idempotency-probe"
    psql(
        primary,
        f"SELECT phase0_submit_batch(1, '{retry_key}', 25);",
        user=APP_USER,
    )
    wait_until(
        lambda: (
            int(
                scalar(
                    standby,
                    f"SELECT count(*) FROM phase0_session_batches WHERE idempotency_key = '{retry_key}';",
                )
            )
            == 1
        ),
        30,
        "synchronous retry probe replay",
    )
    sampled_lsn = lsn(primary)
    failover_prefix = logs / "failover-burst-"
    burst, burst_started = start_pgbench(
        primary,
        scripts["failover"],
        failover_prefix,
        clients=8,
        transactions_per_client=100,
    )
    time.sleep(0.5)
    failover_started = time.perf_counter()
    stop_cluster(primary, "immediate")
    burst_result = finish_pgbench(burst, burst_started, failover_prefix, allow_failure=True)
    run(
        [
            command_path("pg_ctl"),
            "-D",
            str(standby.data_dir),
            "-w",
            "promote",
        ]
    )
    wait_until(
        lambda: scalar(standby, "SELECT pg_is_in_recovery();") == "f",
        30,
        "standby promotion",
    )
    failover_seconds = time.perf_counter() - failover_started
    reconnect_seconds = wait_until(
        lambda: psql(standby, "SELECT 1;", user=APP_USER, check=False).returncode == 0,
        30,
        "application reconnection",
    )
    retry_values = (
        psql(
            standby,
            f"SELECT phase0_submit_batch(1, '{retry_key}', 25);"
            f"SELECT phase0_submit_batch(1, '{retry_key}', 25);",
            user=APP_USER,
        )
        .stdout.strip()
        .splitlines()
    )
    promoted_lsn = lsn(standby)
    counts = workload_counts(standby)
    missing_outbox = int(
        scalar(
            standby,
            "SELECT count(*) FROM phase0_session_batches batches "
            "LEFT JOIN phase0_outbox_events events "
            "ON events.tenant_id = batches.tenant_id AND events.batch_id = batches.id "
            "WHERE events.id IS NULL;",
        )
    )
    duplicate_outbox = int(
        scalar(
            standby,
            "SELECT count(*) FROM (SELECT tenant_id, batch_id FROM phase0_outbox_events "
            "GROUP BY tenant_id, batch_id HAVING count(*) > 1) duplicates;",
        )
    )
    retry_batches = int(
        scalar(
            standby,
            f"SELECT count(*) FROM phase0_session_batches WHERE idempotency_key = '{retry_key}';",
        )
    )
    sampled_lsn_present = (
        scalar(standby, f"SELECT pg_wal_lsn_diff('{promoted_lsn}', '{sampled_lsn}') >= 0;") == "t"
    )
    return {
        "sampled_primary_lsn": sampled_lsn,
        "promoted_lsn": promoted_lsn,
        "failover_rto_ms": round(failover_seconds * 1000, 3),
        "application_reconnect_ms": round(reconnect_seconds * 1000, 3),
        "interrupted_burst": burst_result,
        "promoted_counts": counts,
        "committed_write_rpo_bytes": 0 if sampled_lsn_present else None,
        "missing_outbox_events": missing_outbox,
        "duplicate_outbox_events": duplicate_outbox,
        "assertions": {
            "burst_was_interrupted": burst_result["exit_code"] != 0,
            "sampled_synchronous_lsn_present": sampled_lsn_present,
            "known_commit_present": retry_batches == 1,
            "idempotent_retry_deduplicated": retry_values == ["0", "0"],
            "no_committed_batch_missing_outbox": missing_outbox == 0,
            "no_duplicate_outbox_fact": duplicate_outbox == 0,
        },
    }


def directory_size(path: Path) -> int:
    return sum(file.stat().st_size for file in path.rglob("*") if file.is_file())


def source_record() -> dict[str, Any]:
    sources = [
        ROOT / "tools/measure_phase0_capacity_recovery.py",
        TARGET_PATH,
    ]
    revision = run(["git", "rev-parse", "HEAD"]).stdout.strip()
    dirty = run(["git", "status", "--porcelain"]).stdout.strip()
    return {
        "git_revision": revision,
        "working_tree": "dirty" if dirty else "clean",
        "artifacts_sha256": {
            str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sources
        },
    }


def environment_record(primary: Cluster) -> dict[str, Any]:
    settings = scalar(
        primary,
        "SELECT name || '=' || setting FROM pg_settings WHERE name IN "
        "('archive_mode','fsync','full_page_writes','hot_standby','max_connections',"
        "'max_wal_senders','shared_buffers','synchronous_commit','wal_level') ORDER BY name;",
        database="postgres",
    ).splitlines()
    memory = run(["sysctl", "-n", "hw.memsize"]).stdout.strip()
    cpu = run(["sysctl", "-n", "hw.ncpu"]).stdout.strip()
    model = run(["sysctl", "-n", "hw.model"]).stdout.strip()
    return {
        "operating_system": platform.platform(),
        "architecture": platform.machine(),
        "machine_model": model,
        "cpu_count": int(cpu),
        "memory_bytes": int(memory),
        "postgresql_version": scalar(primary, "SHOW server_version;", database="postgres"),
        "postgresql_settings": dict(setting.split("=", maxsplit=1) for setting in settings),
        "topology": "local disposable primary, physical standby, WAL archive, and isolated PITR restore",
    }


def summarize_capacity(runs: list[dict[str, Any]]) -> dict[str, Any]:
    fact_rates = [run_item["bounded"]["facts_per_second"] for run_item in runs]
    p95_values = [run_item["bounded"]["latency_ms"]["p95"] for run_item in runs]
    return {
        "facts_per_second": distribution(fact_rates),
        "session_batch_p95_ms": distribution(p95_values),
        "all_atomicity_and_authorization_assertions_passed": all(
            all(run_item["assertions"].values()) for run_item in runs
        ),
    }


def distribution(values: list[float]) -> dict[str, float]:
    return {
        "min": round(min(values), 3),
        "median": round(statistics.median(values), 3),
        "max": round(max(values), 3),
    }


def target_metrics(targets: dict[str, Any], target_id: str) -> dict[str, Any]:
    for target in targets["targets"]:
        if target["id"] == target_id:
            return target["metrics"]
    raise MeasurementError(f"target is missing: {target_id}")


def evaluate_result(
    targets: dict[str, Any],
    capacity_summary: dict[str, Any],
    noisy: dict[str, Any],
    connection_exhaustion: dict[str, Any],
    pitr: dict[str, Any],
    replica: dict[str, Any],
    failover: dict[str, Any],
) -> dict[str, Any]:
    write_target = target_metrics(targets, "peak_domain_writes")
    placement_target = target_metrics(targets, "tenant_placement")
    ha_target = target_metrics(targets, "database_ha")
    recovery_target = target_metrics(targets, "database_recovery")
    checks = {
        "bounded_fact_rate": capacity_summary["facts_per_second"]["min"]
        >= write_target["committed_facts_per_second_min"],
        "bounded_batch_p95": capacity_summary["session_batch_p95_ms"]["max"]
        <= write_target["p95_session_batch_duration_ms_max"],
        "atomicity_and_authorization": capacity_summary[
            "all_atomicity_and_authorization_assertions_passed"
        ],
        "noisy_tenant_degradation": noisy["other_tenant_p95_degradation_percent"]["max"]
        <= placement_target["other_tenant_p95_degradation_percent_max"],
        "connection_exhaustion_rejects_before_transaction": connection_exhaustion[
            "rejected_before_transaction"
        ],
        "replica_security_route_never_stale": not replica["paused_replay"][
            "security_sensitive_route_used_stale_state"
        ],
        "replica_outage_rejects_bounded_staleness": replica["standby_outage"][
            "bounded_staleness_route_decision"
        ]
        == "reject",
        "recovery_conflict_is_bounded": replica["recovery_conflict"]["long_query_cancelled"],
        "failover_rto": failover["failover_rto_ms"] <= ha_target["failover_rto_seconds_max"] * 1000,
        "application_reconnect": failover["application_reconnect_ms"]
        <= ha_target["application_reconnect_seconds_max"] * 1000,
        "committed_write_rpo": failover["committed_write_rpo_bytes"]
        == ha_target["committed_write_rpo_bytes_max"],
        "outbox_continuity": failover["missing_outbox_events"]
        <= ha_target["missing_outbox_events_max"],
        "failover_safety_assertions": all(failover["assertions"].values()),
        "pitr_rto": pitr["restore_rto_ms"] <= recovery_target["pitr_rto_seconds_max"] * 1000,
        "pitr_integrity": all(pitr["assertions"].values()),
    }
    return {
        "checks": checks,
        "passed": all(checks.values()),
        "disposition": (
            "local_targets_passed_managed_confirmation_required"
            if all(checks.values())
            else "local_measurement_has_failed_target"
        ),
    }


def measure(repetitions: int, retained_rows: int) -> dict[str, Any]:
    targets = json.loads(TARGET_PATH.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(
        prefix="chim-phase0-capacity-recovery-", dir="/tmp"
    ) as temporary:
        base = Path(temporary)
        archive_dir = base / "archive"
        archive_dir.mkdir()
        logs = base / "pgbench-logs"
        logs.mkdir()
        scripts = workload_files(base)
        primary = init_cluster(base, "primary", free_port(), archive_dir)
        standby: Cluster | None = None
        restore: Cluster | None = None
        try:
            start_cluster(primary)
            setup_database(primary)
            environment = environment_record(primary)
            print("capacity: running repeated five-school burst and comparison", flush=True)
            capacity_runs = [
                capacity_run(primary, scripts, logs, repetition)
                for repetition in range(1, repetitions + 1)
            ]
            capacity_summary = summarize_capacity(capacity_runs)
            print("capacity: running noisy-tenant and connection-exhaustion cases", flush=True)
            noisy = noisy_tenant_measurement(primary, scripts, logs, repetitions)
            connection_exhaustion = connection_exhaustion_measurement(primary)
            print("recovery: creating and validating isolated point-in-time restore", flush=True)
            pitr, restore = create_pitr_restore(base, primary, archive_dir, retained_rows)
            print("recovery: creating physical standby and exercising lag/outage", flush=True)
            standby = create_standby(base, primary)
            replica = replica_measurements(primary, standby)
            print("recovery: interrupting a burst and promoting the standby", flush=True)
            failover = failover_measurement(primary, standby, scripts, logs)
            evaluation = evaluate_result(
                targets,
                capacity_summary,
                noisy,
                connection_exhaustion,
                pitr,
                replica,
                failover,
            )
            return {
                "schema_version": 1,
                "status": "phase0_local_evidence",
                "measured_on": datetime.now(UTC).date().isoformat(),
                "source": source_record(),
                "command": (
                    "mise exec -- uv run python tools/measure_phase0_capacity_recovery.py "
                    "--repetitions 3 --retained-rows 1312000 "
                    "--output spikes/ash-foundation-lab/priv/maintenance/"
                    "capacity-recovery-measurement.json"
                ),
                "target_recommendation_sha256": hashlib.sha256(
                    TARGET_PATH.read_bytes()
                ).hexdigest(),
                "environment": environment,
                "envelope": targets["profile"],
                "capacity": {
                    "runs": capacity_runs,
                    "summary": capacity_summary,
                    "noisy_tenant": noisy,
                    "connection_exhaustion": connection_exhaustion,
                },
                "recovery": {
                    "pitr": pitr,
                    "replica": replica,
                    "failover": failover,
                },
                "evaluation": evaluation,
                "limits": [
                    "Local Apple Silicon results do not size or accept a managed production service tier.",
                    "PITR uses 1,312,000 retained synthetic rows, one percent of the 131,200,000-row attendance planning horizon; full-horizon managed restore remains required.",
                    "The physical standby shares one host and filesystem, so it exercises PostgreSQL choreography rather than zone or regional failure independence.",
                    "The workload uses a neutral SQL contract that represents the future named batch action; it is not a production attendance module or Ash bulk-strategy benchmark.",
                    "Web, file, object-store, report-renderer, production identity, durable movement, and managed-provider evidence are outside this local run.",
                ],
            }
        finally:
            if restore is not None:
                stop_cluster(restore)
            if standby is not None:
                stop_cluster(standby)
            stop_cluster(primary)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--retained-rows", type=int, default=1_312_000)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.repetitions < 1 or args.retained_rows < 1:
        raise SystemExit("repetitions and retained rows must be positive")
    result = measure(args.repetitions, args.retained_rows)
    output = args.output if args.output.is_absolute() else ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {output}", flush=True)
    print(result["evaluation"]["disposition"], flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
