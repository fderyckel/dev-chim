import importlib.util
from pathlib import Path


def load_checker():
    root = Path(__file__).resolve().parents[2]
    module_path = root / "tools/check_docs.py"
    spec = importlib.util.spec_from_file_location("check_docs", module_path)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


checker = load_checker()


def test_current_repository_documentation_contract_passes() -> None:
    assert checker.validate_repository(checker.repository_root()) == []


def test_markdown_errors_report_a_broken_relative_link(tmp_path: Path) -> None:
    document = tmp_path / "README.md"
    document.write_text("# Example\n\n[Missing](missing.md)\n", encoding="utf-8")

    assert checker.markdown_errors(document, tmp_path) == [
        "README.md: broken relative link 'missing.md'"
    ]


def test_phase_archive_rejects_an_extra_document(tmp_path: Path) -> None:
    for relative_path in checker.PHASE_ARCHIVE_PATHS:
        path = tmp_path / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("# Archive\n", encoding="utf-8")
    extra = tmp_path / "docs/phase-0/old-report.md"
    extra.write_text("# Old report\n", encoding="utf-8")

    assert checker.phase_archive_errors(tmp_path) == [
        "phase archive has unexpected documents: docs/phase-0/old-report.md"
    ]


def test_generated_and_dependency_markdown_is_ignored(tmp_path: Path) -> None:
    maintained = tmp_path / "docs/README.md"
    generated = tmp_path / "clients/web/node_modules/package/README.md"
    maintained.parent.mkdir(parents=True)
    generated.parent.mkdir(parents=True)
    maintained.write_text("# Docs\n", encoding="utf-8")
    generated.write_text("not maintained", encoding="utf-8")

    assert list(checker.iter_markdown(tmp_path)) == [maintained]
