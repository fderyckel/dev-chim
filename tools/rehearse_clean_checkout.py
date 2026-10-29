"""Bootstrap and verify staged changes in a temporary clean checkout."""

from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class RehearsalError(RuntimeError):
    """Raised when the isolated candidate cannot be reproduced or verified."""


def run(
    command: list[str],
    *,
    cwd: Path,
    input_text: str | None = None,
    env: dict[str, str] | None = None,
    stream: bool = False,
) -> subprocess.CompletedProcess[str]:
    """Run a bounded command without a shell."""
    completed = subprocess.run(
        command,
        check=False,
        cwd=cwd,
        env=env,
        input=input_text,
        text=True,
        stdout=None if stream else subprocess.PIPE,
        stderr=None if stream else subprocess.PIPE,
    )
    if completed.returncode != 0:
        detail = "" if stream else f"\n{completed.stderr.strip()}"
        raise RehearsalError(
            f"command failed ({completed.returncode}): {' '.join(command)}{detail}"
        )
    return completed


def materialize_candidate(checkout: Path) -> None:
    """Create an isolated commit from HEAD plus the staged patch."""
    run(
        [
            "git",
            "clone",
            "--quiet",
            "--no-local",
            "--no-hardlinks",
            str(ROOT),
            str(checkout),
        ],
        cwd=ROOT,
    )
    patch = run(["git", "diff", "--cached", "--binary"], cwd=ROOT).stdout
    if patch:
        run(["git", "apply", "--binary"], cwd=checkout, input_text=patch)
    run(["git", "add", "--all"], cwd=checkout)
    run(
        [
            "git",
            "-c",
            "user.name=Clean checkout rehearsal",
            "-c",
            "user.email=clean-checkout-rehearsal.invalid",
            "commit",
            "--quiet",
            "--allow-empty",
            "-m",
            "Temporary clean-checkout candidate",
        ],
        cwd=checkout,
    )


def require_clean(checkout: Path, stage: str) -> None:
    """Reject tracked or untracked source changes after a rehearsal stage."""
    status = run(["git", "status", "--porcelain"], cwd=checkout).stdout
    if status:
        raise RehearsalError(f"temporary checkout is dirty after {stage}")


def rehearse() -> None:
    """Build, bootstrap, and check the staged candidate in a temporary clone."""
    with tempfile.TemporaryDirectory(prefix="chim-clean-checkout-", dir="/tmp") as temporary:
        checkout = Path(temporary) / "dev-chim"
        materialize_candidate(checkout)
        require_clean(checkout, "candidate creation")

        print("clean-checkout: bootstrapping isolated candidate", flush=True)
        run(["./bin/bootstrap"], cwd=checkout, stream=True)
        require_clean(checkout, "bootstrap")

        print("clean-checkout: running changed-boundary checks", flush=True)
        check_environment = os.environ.copy()
        check_environment["CHIMWEMWE_CLEAN_CHECKOUT_REHEARSAL"] = "1"
        run(
            ["make", "check-changed"],
            cwd=checkout,
            env=check_environment,
            stream=True,
        )
        require_clean(checkout, "verification")


def main() -> int:
    rehearse()
    print("Clean-checkout verification passed.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
