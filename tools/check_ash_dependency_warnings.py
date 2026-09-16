"""Compile the Ash framework dependencies and enforce a reviewed warning baseline."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from collections import Counter
from datetime import date
from pathlib import Path
from typing import Any

COMPILE_COMMAND = ("mix", "deps.compile", "--force")
ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
PACKAGE_HEADER = re.compile(r"^==> (?P<package>[a-z0-9_]+)$")
WARNING_HEADER = re.compile(r"^\s*warning:\s*(?P<message>.+?)\s*$")
LOCATION = re.compile(
    r"^\s*└─ (?:\([^)]+\) )?(?P<path>[^:]+):(?P<line>\d+)"
    r"(?::(?P<column>\d+))?(?:: (?P<subject>.*))?$"
)
ERLANG_WARNING = re.compile(
    r"^(?:.+/)?deps/(?P<package>[a-z0-9_]+)/(?P<path>[^:]+):(?P<line>\d+):"
    r"(?P<column>\d+): Warning: (?P<message>.+)$"
)
NATIVE_WARNING = re.compile(r"^(?P<tool>[^:]+): warning: (?P<message>.+)$")


class WarningBaselineError(RuntimeError):
    """Raised when warning evidence cannot be captured or does not match."""


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def baseline_path(root: Path) -> Path:
    return root / "spikes/ash-foundation-lab/priv/maintenance/ash-dependency-warnings.json"


def spike_root(root: Path) -> Path:
    return root / "spikes/ash-foundation-lab"


def normalize_text(value: str) -> str:
    return " ".join(value.split())


def parse_warning_output(output: str) -> list[dict[str, Any]]:
    """Return stable warning groups from Mix dependency compiler output."""
    lines = ANSI_ESCAPE.sub("", output).splitlines()
    warnings: list[dict[str, Any]] = []
    package: str | None = None
    current: dict[str, Any] | None = None

    def finish_warning() -> None:
        nonlocal current
        if current is None:
            return
        current["locations"] = sorted(
            current["locations"],
            key=lambda location: (
                location["path"],
                location["line"],
                location.get("column", 0),
                location.get("subject", ""),
            ),
        )
        warnings.append(current)
        current = None

    for line in lines:
        package_match = PACKAGE_HEADER.match(line)
        if package_match:
            finish_warning()
            package = package_match.group("package")
            continue

        erlang_match = ERLANG_WARNING.match(line)
        if erlang_match:
            finish_warning()
            warnings.append(
                {
                    "package": erlang_match.group("package"),
                    "message": normalize_text(erlang_match.group("message")),
                    "locations": [
                        {
                            "path": erlang_match.group("path"),
                            "line": int(erlang_match.group("line")),
                            "column": int(erlang_match.group("column")),
                        }
                    ],
                }
            )
            continue

        warning_match = WARNING_HEADER.match(line)
        if warning_match:
            finish_warning()
            if package is None:
                raise WarningBaselineError("warning appeared before a dependency package header")
            current = {
                "package": package,
                "message": normalize_text(warning_match.group("message")),
                "locations": [],
            }
            continue

        native_match = NATIVE_WARNING.match(line)
        if native_match:
            finish_warning()
            if package is None:
                raise WarningBaselineError("native warning appeared before a package header")
            warnings.append(
                {
                    "package": package,
                    "message": normalize_text(
                        f"{native_match.group('tool')}: {native_match.group('message')}"
                    ),
                    "locations": [],
                }
            )
            continue

        if "╰── Warning:" in line:
            continue

        if "warning:" in line.lower():
            raise WarningBaselineError(f"unrecognized warning format: {line.strip()}")

        if current is None:
            continue

        location_match = LOCATION.match(line)
        if not location_match:
            continue

        location: dict[str, Any] = {
            "path": location_match.group("path"),
            "line": int(location_match.group("line")),
        }
        if column := location_match.group("column"):
            location["column"] = int(column)
        if subject := location_match.group("subject"):
            location["subject"] = normalize_text(subject)
        current["locations"].append(location)

    finish_warning()
    return sorted(
        warnings,
        key=lambda warning: (
            warning["package"],
            warning["message"],
            canonical_record(warning),
        ),
    )


def canonical_record(record: dict[str, Any]) -> str:
    return json.dumps(record, sort_keys=True, separators=(",", ":"))


def locked_package_versions(lock_text: str) -> dict[str, str]:
    pattern = re.compile(
        r'^\s*"(?P<name>[a-z0-9_]+)": \{:hex, :[a-z0-9_]+, "(?P<version>[^"]+)"',
        re.MULTILINE,
    )
    versions = {
        match.group("name"): match.group("version") for match in pattern.finditer(lock_text)
    }
    if not versions:
        raise WarningBaselineError("cannot find Hex dependency versions in the spike mix.lock")
    return dict(sorted(versions.items()))


def current_toolchain() -> dict[str, str]:
    command = [
        "elixir",
        "-e",
        'IO.puts("#{System.version()}|#{:erlang.system_info(:otp_release)}")',
    ]
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise WarningBaselineError(f"cannot inspect Elixir/OTP toolchain: {result.stderr.strip()}")

    parts = result.stdout.strip().split("|", maxsplit=1)
    if len(parts) != 2 or not all(parts):
        raise WarningBaselineError("Elixir/OTP toolchain probe returned malformed output")
    return {"elixir": parts[0], "otp": parts[1]}


def compile_dependency_warnings(root: Path) -> list[dict[str, Any]]:
    environment = os.environ.copy()
    environment["MIX_ENV"] = "test"
    result = subprocess.run(
        COMPILE_COMMAND,
        cwd=spike_root(root),
        env=environment,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    if result.returncode != 0:
        tail = "\n".join(result.stdout.splitlines()[-40:])
        raise WarningBaselineError(
            f"dependency compilation failed with exit code {result.returncode}:\n{tail}"
        )
    return parse_warning_output(result.stdout)


def current_document(root: Path) -> dict[str, Any]:
    lock_text = (spike_root(root) / "mix.lock").read_text(encoding="utf-8")
    return {
        "schema_version": 1,
        "status": "phase0_evidence",
        "owner": "Platform engineering",
        "reviewed_on": date.today().isoformat(),
        "scope": {
            "command": list(COMPILE_COMMAND),
            "packages": locked_package_versions(lock_text),
            "mix_lock_sha256": hashlib.sha256(lock_text.encode()).hexdigest(),
            "toolchain": current_toolchain(),
        },
        "allowed_delta": {"added": 0, "removed": 0},
        "warnings": compile_dependency_warnings(root),
    }


def validate_baseline(baseline: dict[str, Any]) -> None:
    required = {
        "schema_version",
        "status",
        "owner",
        "reviewed_on",
        "scope",
        "allowed_delta",
        "warnings",
    }
    if set(baseline) != required:
        raise WarningBaselineError("warning baseline has an unexpected top-level shape")
    if baseline["schema_version"] != 1 or baseline["status"] != "phase0_evidence":
        raise WarningBaselineError("warning baseline has an unsupported schema or status")
    if not isinstance(baseline["owner"], str) or not baseline["owner"].strip():
        raise WarningBaselineError("warning baseline owner must be non-empty")
    try:
        date.fromisoformat(baseline["reviewed_on"])
    except (TypeError, ValueError) as error:
        raise WarningBaselineError("warning baseline reviewed_on must be an ISO date") from error

    scope = baseline["scope"]
    if not isinstance(scope, dict) or set(scope) != {
        "command",
        "packages",
        "mix_lock_sha256",
        "toolchain",
    }:
        raise WarningBaselineError("warning baseline scope has an unexpected shape")
    if scope["command"] != list(COMPILE_COMMAND):
        raise WarningBaselineError("warning baseline compile command is not governed")
    packages = scope["packages"]
    if (
        not isinstance(packages, dict)
        or not packages
        or any(
            not isinstance(name, str) or not name or not isinstance(version, str) or not version
            for name, version in packages.items()
        )
    ):
        raise WarningBaselineError("warning baseline packages must be a non-empty map")
    if not isinstance(scope["mix_lock_sha256"], str) or not re.fullmatch(
        r"[0-9a-f]{64}", scope["mix_lock_sha256"]
    ):
        raise WarningBaselineError("warning baseline mix.lock digest is malformed")
    toolchain = scope["toolchain"]
    if (
        not isinstance(toolchain, dict)
        or set(toolchain) != {"elixir", "otp"}
        or any(not isinstance(value, str) or not value for value in toolchain.values())
    ):
        raise WarningBaselineError("warning baseline toolchain is malformed")

    if baseline["allowed_delta"] != {"added": 0, "removed": 0}:
        raise WarningBaselineError("warning baseline must enforce a zero added/removed delta")
    if not isinstance(baseline["warnings"], list):
        raise WarningBaselineError("warning baseline warnings must be a list")
    for warning in baseline["warnings"]:
        validate_warning_record(warning, packages)


def validate_warning_record(record: Any, packages: dict[str, str]) -> None:
    if not isinstance(record, dict) or set(record) != {"package", "message", "locations"}:
        raise WarningBaselineError("warning baseline contains a malformed warning record")
    if record["package"] not in packages:
        raise WarningBaselineError(
            f"warning baseline references unlocked package: {record['package']}"
        )
    if not isinstance(record["message"], str) or not record["message"].strip():
        raise WarningBaselineError("warning baseline contains an empty warning message")
    if not isinstance(record["locations"], list):
        raise WarningBaselineError("warning baseline warning locations must be a list")

    for location in record["locations"]:
        if (
            not isinstance(location, dict)
            or not {"path", "line"}.issubset(location)
            or not set(location).issubset({"path", "line", "column", "subject"})
            or not isinstance(location["path"], str)
            or not location["path"]
            or not isinstance(location["line"], int)
            or isinstance(location["line"], bool)
            or location["line"] < 1
        ):
            raise WarningBaselineError("warning baseline contains a malformed location")
        if "column" in location and (
            not isinstance(location["column"], int)
            or isinstance(location["column"], bool)
            or location["column"] < 1
        ):
            raise WarningBaselineError("warning baseline contains a malformed column")
        if "subject" in location and (
            not isinstance(location["subject"], str) or not location["subject"].strip()
        ):
            raise WarningBaselineError("warning baseline contains a malformed subject")


def compare_documents(baseline: dict[str, Any], current: dict[str, Any]) -> None:
    validate_baseline(baseline)
    if baseline["scope"] != current["scope"]:
        raise WarningBaselineError(
            "warning baseline scope changed; review toolchain, package versions, and command"
        )

    expected = Counter(canonical_record(record) for record in baseline["warnings"])
    observed = Counter(canonical_record(record) for record in current["warnings"])
    added = list((observed - expected).elements())
    removed = list((expected - observed).elements())
    if not added and not removed:
        return

    details = []
    if added:
        details.append(f"added={len(added)}: " + "; ".join(added))
    if removed:
        details.append(f"removed={len(removed)}: " + "; ".join(removed))
    raise WarningBaselineError("dependency warning delta is not zero\n" + "\n".join(details))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--print-current",
        action="store_true",
        help="print the current normalized document for explicit baseline review",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = repository_root()
    try:
        current = current_document(root)
        if args.print_current:
            print(json.dumps(current, indent=2, sort_keys=False))
            return 0

        path = baseline_path(root)
        baseline = json.loads(path.read_text(encoding="utf-8"))
        compare_documents(baseline, current)
    except (OSError, json.JSONDecodeError, WarningBaselineError) as error:
        print(f"Ash dependency warning check failed: {error}", file=sys.stderr)
        return 1

    warning_count = len(current["warnings"])
    print(f"Ash dependency warning baseline matches: {warning_count} warning groups, zero delta.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
