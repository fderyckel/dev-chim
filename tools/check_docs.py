"""Validate current repository documentation and ADR conventions."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote

ALLOWED_ADR_STATUSES = {
    "Accepted",
    "Conditionally Accepted",
    "Deferred",
    "Proposed",
    "Rejected",
    "Superseded",
    "Template",
}

REQUIRED_PATHS = (
    "README.md",
    "AGENTS.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "docs/README.md",
    "docs/architecture/README.md",
    "docs/adr/README.md",
    "docs/security/threat-model.md",
    "docs/phase-0/README.md",
    "docs/phase-0/handover-evidence.md",
    "docs/phase-1/README.md",
    "docs/phase-1/handover-evidence.md",
    "docs/phase-2/README.md",
)

PHASE_ARCHIVE_PATHS = {
    "docs/phase-0/README.md",
    "docs/phase-0/handover-evidence.md",
    "docs/phase-1/README.md",
    "docs/phase-1/handover-evidence.md",
}

REQUIRED_ADR_HEADINGS = (
    "## Context",
    "## Decision drivers",
    "## Considered options",
    "## Decision",
    "## Consequences",
    "## Security, privacy, operability, and migration effects",
    "## Validation evidence",
    "## Fallback and exit cost",
    "## Review triggers",
    "## Related records",
)

IGNORED_DIRECTORY_NAMES = {
    ".git",
    ".venv",
    "_build",
    "deps",
    "node_modules",
    "playwright-report",
    "test-results",
}

LINK_PATTERN = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")
STATUS_PATTERN = re.compile(r"^- Status: (.+)$", re.MULTILINE)
ADR_FILENAME_PATTERN = re.compile(r"^(\d{4})-[a-z0-9-]+\.md$")
ADR_INDEX_PATTERN = re.compile(
    r"^\| \[(\d{4})\]\(([^)]+)\) \| [^|]+ \| ([^|]+) \|",
    re.MULTILINE,
)


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def iter_markdown(root: Path):
    """Yield maintained Markdown files, excluding generated and dependency trees."""
    for path in sorted(root.rglob("*.md")):
        if any(part in IGNORED_DIRECTORY_NAMES for part in path.relative_to(root).parts):
            continue
        yield path


def markdown_errors(path: Path, root: Path) -> list[str]:
    """Return structural and relative-link errors for one Markdown document."""
    errors: list[str] = []
    body = path.read_text(encoding="utf-8")
    lines = body.splitlines()
    relative_path = path.relative_to(root)

    if sum(line.startswith("# ") for line in lines) != 1:
        errors.append(f"{relative_path}: expected exactly one H1")

    if any(line.endswith((" ", "\t")) for line in lines):
        errors.append(f"{relative_path}: trailing whitespace")

    for raw_target in LINK_PATTERN.findall(body):
        target = raw_target.strip().split(maxsplit=1)[0]
        if target.startswith(("#", "http://", "https://", "mailto:")):
            continue
        relative_target = unquote(target.split("#", maxsplit=1)[0])
        if not relative_target:
            continue
        resolved = (path.parent / relative_target).resolve()
        if not resolved.exists():
            errors.append(f"{relative_path}: broken relative link {relative_target!r}")

    return errors


def phase_archive_errors(root: Path) -> list[str]:
    """Keep the completed Phase 0 and Phase 1 archives intentionally small."""
    actual = {
        str(path.relative_to(root))
        for phase in ("phase-0", "phase-1")
        for path in (root / "docs" / phase).rglob("*.md")
    }
    if actual == PHASE_ARCHIVE_PATHS:
        return []

    errors: list[str] = []
    missing = sorted(PHASE_ARCHIVE_PATHS - actual)
    unexpected = sorted(actual - PHASE_ARCHIVE_PATHS)
    if missing:
        errors.append(f"phase archive is missing: {', '.join(missing)}")
    if unexpected:
        errors.append(f"phase archive has unexpected documents: {', '.join(unexpected)}")
    return errors


def adr_errors(root: Path) -> list[str]:
    """Return errors in ADR numbering, status, headings, and index coverage."""
    errors: list[str] = []
    adr_dir = root / "docs/adr"
    records: dict[str, tuple[Path, str]] = {}

    for path in sorted(adr_dir.glob("[0-9][0-9][0-9][0-9]-*.md")):
        match = ADR_FILENAME_PATTERN.match(path.name)
        if not match:
            errors.append(f"{path.relative_to(root)}: invalid ADR filename")
            continue

        number = match.group(1)
        if number in records:
            errors.append(f"duplicate ADR number {number}")
            continue

        body = path.read_text(encoding="utf-8")
        status_match = STATUS_PATTERN.search(body)
        if not status_match:
            errors.append(f"{path.relative_to(root)}: missing Status metadata")
            status = ""
        else:
            status = status_match.group(1).strip()
            if status not in ALLOWED_ADR_STATUSES:
                errors.append(f"{path.relative_to(root)}: invalid ADR status {status!r}")

        records[number] = (path, status)

    index_body = (adr_dir / "README.md").read_text(encoding="utf-8")
    indexed: dict[str, tuple[str, str]] = {
        number: (target, status.strip())
        for number, target, status in ADR_INDEX_PATTERN.findall(index_body)
    }

    for number, (target, index_status) in indexed.items():
        record = records.get(number)
        if record is None:
            errors.append(f"ADR {number}: indexed record is missing")
            continue
        path, status = record
        if target != path.name:
            errors.append(f"ADR {number}: index target {target!r} != {path.name!r}")
        if index_status != status:
            errors.append(f"ADR {number}: index status {index_status!r} != {status!r}")
        body = path.read_text(encoding="utf-8")
        for heading in REQUIRED_ADR_HEADINGS:
            if heading not in body:
                errors.append(f"{path.relative_to(root)}: missing heading {heading!r}")

    return errors


def validate_repository(root: Path) -> list[str]:
    """Return all current documentation contract errors."""
    errors = [
        f"missing required path: {relative_path}"
        for relative_path in REQUIRED_PATHS
        if not (root / relative_path).exists()
    ]
    errors.extend(phase_archive_errors(root))
    errors.extend(adr_errors(root))
    for path in iter_markdown(root):
        errors.extend(markdown_errors(path, root))
    return errors


def main() -> int:
    errors = validate_repository(repository_root())
    if errors:
        print("Repository documentation validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Repository documentation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
