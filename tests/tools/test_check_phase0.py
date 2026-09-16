from __future__ import annotations

import importlib.util
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


def test_broken_relative_link_is_reported(tmp_path: Path) -> None:
    document = tmp_path / "document.md"
    document.write_text("# Document\n\n[Missing](missing.md)\n", encoding="utf-8")

    assert CHECKER.markdown_errors(document, tmp_path) == [
        "document.md: broken relative link 'missing.md'"
    ]


def test_exit_review_rejects_unresolved_phase_zero_state() -> None:
    errors = CHECKER.exit_review_errors(ROOT)

    assert any("TARGET_REQUIRED" in error for error in errors)
    assert any("still Proposed" in error for error in errors)


def test_exit_review_rejects_unresolved_postgresql_availability_evidence() -> None:
    errors = CHECKER.exit_review_errors(ROOT)

    assert any(
        "docs/phase-0/evidence/postgresql-availability-and-burst.md" in error
        and "EVIDENCE_REQUIRED" in error
        and "DECISION_REQUIRED" in error
        and "NOT_RUN" in error
        for error in errors
    )


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
        "Phase 1 slices 1A through 1C permit only apps/chimwemwe_core; unexpected apps: attendance"
    ]
