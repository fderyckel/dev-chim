"""Rehearse bootstrap and the complete check from an isolated clean Git checkout."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "spikes/ash-foundation-lab/priv/maintenance/clean-checkout-rehearsal.json"


class RehearsalError(RuntimeError):
    """Raised when the isolated candidate cannot be reproduced or verified."""


def run(
    command: list[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    """Run a bounded command without a shell."""
    completed = subprocess.run(
        command,
        check=False,
        capture_output=True,
        cwd=cwd,
        input=input_text,
        text=True,
    )
    if check and completed.returncode != 0:
        raise RehearsalError(
            f"command failed ({completed.returncode}): {' '.join(command)}\n"
            f"{completed.stderr.strip()}"
        )
    return completed


def run_streamed(command: list[str], *, cwd: Path) -> tuple[int, str, float]:
    """Stream a long verification command while retaining a bounded summary source."""
    started = time.perf_counter()
    process = subprocess.Popen(
        command,
        cwd=cwd,
        stderr=subprocess.STDOUT,
        stdout=subprocess.PIPE,
        text=True,
    )
    assert process.stdout is not None
    lines: list[str] = []
    summary_lines: list[str] = []
    for line in process.stdout:
        print(line, end="", flush=True)
        stripped = line.rstrip()
        lines.append(stripped)
        if (
            " passed in " in stripped
            or stripped.startswith("Result: ")
            or stripped.lstrip().startswith("Tests ")
        ):
            summary_lines.append(stripped)
        if len(lines) > 400:
            lines.pop(0)
    retained = [*summary_lines, *lines]
    return process.wait(), "\n".join(dict.fromkeys(retained)), time.perf_counter() - started


def file_sha256(path: Path) -> str:
    """Return a SHA-256 digest."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def materialize_candidate(checkout: Path) -> dict[str, Any]:
    """Create a local-only candidate commit from HEAD plus every current change."""
    run(
        [
            "git",
            "clone",
            "--quiet",
            "--no-local",
            "--no-hardlinks",
            str(ROOT),
            str(checkout),
        ]
    )
    patch = run(["git", "diff", "--binary", "HEAD"], cwd=ROOT).stdout
    if patch:
        run(["git", "apply", "--binary"], cwd=checkout, input_text=patch)

    raw_untracked = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard", "-z"],
        check=True,
        capture_output=True,
        cwd=ROOT,
    ).stdout
    untracked = [Path(item.decode()) for item in raw_untracked.split(b"\0") if item]
    for relative in untracked:
        source = ROOT / relative
        destination = checkout / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.is_symlink():
            destination.symlink_to(os.readlink(source))
        else:
            shutil.copy2(source, destination)

    run(["git", "add", "--all"], cwd=checkout)
    staged_tree = run(["git", "write-tree"], cwd=checkout).stdout.strip()
    run(
        [
            "git",
            "-c",
            "user.name=Phase 0 rehearsal",
            "-c",
            "user.email=phase0-rehearsal.invalid",
            "commit",
            "--quiet",
            "-m",
            "Temporary clean-checkout rehearsal candidate",
        ],
        cwd=checkout,
    )
    candidate_commit = run(["git", "rev-parse", "HEAD"], cwd=checkout).stdout.strip()
    status = run(["git", "status", "--porcelain"], cwd=checkout).stdout
    if status:
        raise RehearsalError("candidate checkout is dirty before bootstrap")
    return {
        "base_revision": run(["git", "rev-parse", "HEAD"], cwd=ROOT).stdout.strip(),
        "candidate_tree": staged_tree,
        "candidate_commit": candidate_commit,
        "tracked_patch_applied": bool(patch),
        "untracked_paths_copied": len(untracked),
        "clean_before_bootstrap": True,
    }


def extracted_counts(output: str) -> dict[str, int]:
    """Extract only stable suite totals from the streamed verification output."""
    import re

    counts: dict[str, int] = {}
    pytest_match = re.search(r"(\d+) passed in [0-9.]+s", output)
    if pytest_match:
        counts["repository_tool_tests"] = int(pytest_match.group(1))
    exunit_matches = re.findall(r"Result: (\d+) passed", output)
    if exunit_matches:
        counts["elixir_test_results"] = sum(int(value) for value in exunit_matches)
    typescript_match = re.search(r"Tests\s+(\d+) passed", output)
    if typescript_match:
        counts["typescript_tests"] = int(typescript_match.group(1))
    return counts


def rehearse() -> dict[str, Any]:
    """Build, bootstrap, and check the current candidate from a temporary clone."""
    started = time.perf_counter()
    with tempfile.TemporaryDirectory(prefix="chim-phase0-clean-checkout-", dir="/tmp") as temporary:
        checkout = Path(temporary) / "dev-chim"
        candidate = materialize_candidate(checkout)
        print("clean-checkout: bootstrapping isolated candidate", flush=True)
        bootstrap_code, bootstrap_output, bootstrap_seconds = run_streamed(
            ["./bin/bootstrap"], cwd=checkout
        )
        if bootstrap_code != 0:
            raise RehearsalError(
                "clean-checkout bootstrap failed\n" + "\n".join(bootstrap_output.splitlines()[-30:])
            )
        clean_after_bootstrap = not run(["git", "status", "--porcelain"], cwd=checkout).stdout
        if not clean_after_bootstrap:
            raise RehearsalError("bootstrap modified tracked or untracked source files")

        print("clean-checkout: running complete make check", flush=True)
        check_code, check_output, check_seconds = run_streamed(["make", "check"], cwd=checkout)
        clean_after_check = not run(["git", "status", "--porcelain"], cwd=checkout).stdout
        if check_code != 0:
            raise RehearsalError(
                "clean-checkout make check failed\n" + "\n".join(check_output.splitlines()[-40:])
            )
        if not clean_after_check:
            raise RehearsalError("make check modified tracked or untracked source files")

        source_paths = [
            ROOT / "tools/rehearse_phase0_clean_checkout.py",
            ROOT / "Makefile",
            ROOT / "bin/bootstrap",
            ROOT / "bin/phase0-check",
            ROOT / "bin/core-check",
        ]
        return {
            "schema_version": 1,
            "status": "phase0_clean_checkout_rehearsal_passed",
            "rehearsed_on": datetime.now(UTC).date().isoformat(),
            "command": (
                "mise exec -- uv run python tools/rehearse_phase0_clean_checkout.py "
                "--output spikes/ash-foundation-lab/priv/maintenance/"
                "clean-checkout-rehearsal.json"
            ),
            "source_sha256": {
                str(path.relative_to(ROOT)): file_sha256(path) for path in source_paths
            },
            "candidate": candidate,
            "bootstrap": {
                "command": "./bin/bootstrap",
                "exit_code": bootstrap_code,
                "elapsed_ms": round(bootstrap_seconds * 1000, 3),
                "clean_after": clean_after_bootstrap,
            },
            "verification": {
                "command": "make check",
                "exit_code": check_code,
                "elapsed_ms": round(check_seconds * 1000, 3),
                "clean_after": clean_after_check,
                "extracted_test_counts": extracted_counts(check_output),
            },
            "elapsed_ms": round((time.perf_counter() - started) * 1000, 3),
            "limits": [
                "The candidate commit exists only inside the deleted temporary clone; the source working tree and history were not changed.",
                "Ignored dependency and build directories may be created by bootstrap and checks; Git source status remained clean.",
                "This local rehearsal does not establish remote CI, branch protection, or managed-service availability.",
                "The result artifact itself is written only after the isolated run and is therefore validated by the subsequent source-tree make check, not by its own candidate commit.",
            ],
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = rehearse()
    output = args.output if args.output.is_absolute() else ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {output}", flush=True)
    print(result["status"], flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
