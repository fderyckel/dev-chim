from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest


def load_checker():
    root = Path(__file__).resolve().parents[2]
    module_path = root / "tools/check_ash_dependency_warnings.py"
    spec = importlib.util.spec_from_file_location("check_ash_dependency_warnings", module_path)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = load_checker()


def warning_document(warnings):
    return {
        "schema_version": 1,
        "status": "phase0_evidence",
        "owner": "Platform engineering",
        "reviewed_on": "2026-09-15",
        "scope": {
            "command": list(CHECKER.COMPILE_COMMAND),
            "packages": {"ash": "3.33.3", "ash_json_api": "1.7.1", "ash_postgres": "2.13.1"},
            "mix_lock_sha256": "a" * 64,
            "toolchain": {"elixir": "1.20.3", "otp": "29"},
        },
        "allowed_delta": {"added": 0, "removed": 0},
        "warnings": warnings,
    }


def test_warning_output_is_normalized_by_package_message_and_location() -> None:
    output = """
==> ash_postgres
     warning: Igniter.Inflex.singularize/1 is undefined
     │
 784 │ call()
     └─ (ash_postgres 2.13.1) lib/resource_generator/spec.ex:784:25: Example.one/1
     └─ (ash_postgres 2.13.1) lib/resource_generator/spec.ex:807:23: Example.two/1
Generated ash_postgres app
==> ash_json_api
\u001b[33m    warning: unused require Logger\u001b[0m
    └─ lib/request.ex:7:3
==> ash_foundation_lab
/workspace/deps/yamerl/src/yamerl.erl:10:2: Warning: legacy catch is deprecated
    │ ╰── Warning: legacy catch is deprecated
"""

    assert CHECKER.parse_warning_output(output) == [
        {
            "package": "ash_json_api",
            "message": "unused require Logger",
            "locations": [{"path": "lib/request.ex", "line": 7, "column": 3}],
        },
        {
            "package": "ash_postgres",
            "message": "Igniter.Inflex.singularize/1 is undefined",
            "locations": [
                {
                    "path": "lib/resource_generator/spec.ex",
                    "line": 784,
                    "column": 25,
                    "subject": "Example.one/1",
                },
                {
                    "path": "lib/resource_generator/spec.ex",
                    "line": 807,
                    "column": 23,
                    "subject": "Example.two/1",
                },
            ],
        },
        {
            "package": "yamerl",
            "message": "legacy catch is deprecated",
            "locations": [{"path": "src/yamerl.erl", "line": 10, "column": 2}],
        },
    ]


def test_warning_without_source_location_is_still_retained() -> None:
    assert CHECKER.parse_warning_output(
        "==> open_api_spex\nwarning: xref config is deprecated\n"
    ) == [
        {
            "package": "open_api_spex",
            "message": "xref config is deprecated",
            "locations": [],
        }
    ]


def test_warning_before_package_header_fails_closed() -> None:
    with pytest.raises(CHECKER.WarningBaselineError, match="before a dependency package header"):
        CHECKER.parse_warning_output("warning: orphan warning\n")


def test_zero_delta_passes_and_added_or_removed_warning_fails() -> None:
    warning = {
        "package": "ash",
        "message": "the following clause is redundant:",
        "locations": [{"path": "lib/ash/example.ex", "line": 10, "column": 2}],
    }
    baseline = warning_document([warning])

    CHECKER.compare_documents(baseline, warning_document([warning]))

    with pytest.raises(CHECKER.WarningBaselineError, match="added=1"):
        CHECKER.compare_documents(baseline, warning_document([warning, warning]))

    with pytest.raises(CHECKER.WarningBaselineError, match="removed=1"):
        CHECKER.compare_documents(baseline, warning_document([]))


def test_scope_change_and_nonzero_policy_fail_closed() -> None:
    baseline = warning_document([])
    changed_scope = warning_document([])
    changed_scope["scope"]["toolchain"]["otp"] = "30"

    with pytest.raises(CHECKER.WarningBaselineError, match="scope changed"):
        CHECKER.compare_documents(baseline, changed_scope)

    baseline["allowed_delta"]["removed"] = 1
    with pytest.raises(CHECKER.WarningBaselineError, match="zero added/removed delta"):
        CHECKER.compare_documents(baseline, warning_document([]))


def test_malformed_warning_record_and_unknown_package_fail_closed() -> None:
    malformed = warning_document([{"package": "ash", "message": "message"}])
    with pytest.raises(CHECKER.WarningBaselineError, match="malformed warning record"):
        CHECKER.compare_documents(malformed, warning_document([]))

    unlocked = warning_document([{"package": "not_locked", "message": "message", "locations": []}])
    with pytest.raises(CHECKER.WarningBaselineError, match="unlocked package"):
        CHECKER.compare_documents(unlocked, warning_document([]))


def test_locked_framework_versions_are_read_from_mix_lock() -> None:
    lock_text = """
%{
  "ash": {:hex, :ash, "3.33.3", "checksum"},
  "ash_json_api": {:hex, :ash_json_api, "1.7.1", "checksum"},
  "ash_postgres": {:hex, :ash_postgres, "2.13.1", "checksum"}
}
"""

    assert CHECKER.locked_package_versions(lock_text) == {
        "ash": "3.33.3",
        "ash_json_api": "1.7.1",
        "ash_postgres": "2.13.1",
    }
