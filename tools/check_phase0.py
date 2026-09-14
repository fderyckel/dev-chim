"""Validate Phase 0 repository, documentation, and decision conventions."""

from __future__ import annotations

import argparse
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
    ".githooks/pre-push",
    "README.md",
    "AGENTS.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "Brewfile",
    "mise.toml",
    "pyproject.toml",
    "uv.lock",
    "docs/README.md",
    "docs/architecture/README.md",
    "docs/architecture/module-activation-and-lifecycle.md",
    "docs/architecture/postgresql-availability-recovery-and-read-routing.md",
    "docs/architecture/quality-attribute-targets.md",
    "docs/architecture/tenant-placement-and-capacity.md",
    "docs/adr/README.md",
    "docs/adr/0000-template.md",
    "docs/security/threat-model.md",
    "docs/phase-0/README.md",
    "docs/phase-0/decision-register.md",
    "docs/phase-0/evidence/ash-upgrade-exercise.md",
    "docs/phase-0/evidence/module-lifecycle.md",
    "docs/phase-0/evidence/postgresql-availability-and-burst.md",
    "docs/phase-0/evidence/tenant-placement-capacity.md",
    "docs/phase-0/evidence/trusted-routing.md",
    "docs/phase-0/review-record.md",
    "spikes/ash-foundation-lab/mix.exs",
    "spikes/ash-foundation-lab/mix.lock",
    "spikes/ash-foundation-lab/typescript-client-review/package.json",
    "spikes/ash-foundation-lab/typescript-client-review/package-lock.json",
)

REQUIRED_ADR_NUMBERS = {
    "0001",
    "0002",
    "0003",
    "0005",
    "0007",
    "0009",
    "0010",
    "0012",
    "0014",
    "0015",
    "0016",
    "0017",
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

FORBIDDEN_PHASE0_DIRECTORIES = (
    "analytics",
    "apps",
    "infra/production",
    "services/ai-gateway",
    "services/scheduler",
    "web",
)

IGNORED_DIRECTORY_NAMES = {".git", ".venv", "_build", "deps", "node_modules"}

LINK_PATTERN = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")
STATUS_PATTERN = re.compile(r"^- Status: (.+)$", re.MULTILINE)
ADR_FILENAME_PATTERN = re.compile(r"^(\d{4})-[a-z0-9-]+\.md$")
ADR_INDEX_PATTERN = re.compile(
    r"^\| \[(\d{4})\]\(([^)]+)\) \| [^|]+ \| ([^|]+) \|",
    re.MULTILINE,
)


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def markdown_errors(path: Path, root: Path) -> list[str]:
    """Return structural and relative-link errors for one Markdown document."""
    errors: list[str] = []
    body = path.read_text(encoding="utf-8")
    lines = body.splitlines()

    if sum(line.startswith("# ") for line in lines) != 1:
        errors.append(f"{path.relative_to(root)}: expected exactly one H1")

    if any(line.endswith((" ", "\t")) for line in lines):
        errors.append(f"{path.relative_to(root)}: trailing whitespace")

    for raw_target in LINK_PATTERN.findall(body):
        target = raw_target.strip().split(maxsplit=1)[0]
        if target.startswith(("#", "http://", "https://", "mailto:")):
            continue
        relative_target = unquote(target.split("#", maxsplit=1)[0])
        if not relative_target:
            continue
        resolved = (path.parent / relative_target).resolve()
        if not resolved.exists():
            errors.append(f"{path.relative_to(root)}: broken relative link {relative_target!r}")

    return errors


def adr_errors(root: Path) -> list[str]:
    """Return errors in ADR numbering, status, headings, and the ADR index."""
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

        for heading in REQUIRED_ADR_HEADINGS:
            if heading not in body:
                errors.append(f"{path.relative_to(root)}: missing heading {heading!r}")

        records[number] = (path, status)

    missing_numbers = sorted(REQUIRED_ADR_NUMBERS - records.keys())
    if missing_numbers:
        errors.append(f"missing required ADR numbers: {', '.join(missing_numbers)}")

    index_body = (adr_dir / "README.md").read_text(encoding="utf-8")
    indexed: dict[str, tuple[str, str]] = {
        number: (target, status.strip())
        for number, target, status in ADR_INDEX_PATTERN.findall(index_body)
    }

    for number, (path, status) in records.items():
        index_entry = indexed.get(number)
        if index_entry is None:
            errors.append(f"ADR {number}: missing from docs/adr/README.md")
            continue
        target, index_status = index_entry
        if target != path.name:
            errors.append(f"ADR {number}: index target {target!r} != {path.name!r}")
        if index_status != status:
            errors.append(f"ADR {number}: index status {index_status!r} != {status!r}")

    return errors


def threat_model_errors(root: Path) -> list[str]:
    """Check that the Phase 0 threat register retains its mandatory columns."""
    path = root / "docs/security/threat-model.md"
    body = path.read_text(encoding="utf-8")
    errors: list[str] = []

    for threat_number in range(1, 16):
        threat_id = f"TM-{threat_number:02d}"
        matching_lines = [line for line in body.splitlines() if line.startswith(f"| {threat_id} |")]
        if len(matching_lines) != 1:
            errors.append(f"{path.relative_to(root)}: expected one row for {threat_id}")
            continue
        cells = [cell.strip() for cell in matching_lines[0].strip("|").split("|")]
        if len(cells) != 6 or any(not cell for cell in cells):
            errors.append(f"{path.relative_to(root)}: incomplete row for {threat_id}")

    return errors


def exit_review_errors(root: Path) -> list[str]:
    """Return blockers that are allowed during work but forbidden at Phase 0 exit."""
    errors: list[str] = []
    governed = (
        root / "docs/architecture/quality-attribute-targets.md",
        root / "docs/phase-0/evidence/module-lifecycle.md",
        root / "docs/phase-0/evidence/postgresql-availability-and-burst.md",
        root / "docs/phase-0/evidence/quality-targets-approval.md",
        root / "docs/phase-0/evidence/tenant-placement-capacity.md",
        root / "docs/phase-0/review-record.md",
    )
    placeholders = (
        "TARGET_REQUIRED",
        "OWNER_REQUIRED",
        "DATE_REQUIRED",
        "EVIDENCE_REQUIRED",
        "DECISION_REQUIRED",
        "NOT_RUN",
    )

    for path in governed:
        body = path.read_text(encoding="utf-8")
        present = [placeholder for placeholder in placeholders if placeholder in body]
        if present:
            errors.append(
                f"{path.relative_to(root)}: unresolved exit placeholders {', '.join(present)}"
            )

    for path in (root / "docs/adr").glob("[0-9][0-9][0-9][0-9]-*.md"):
        if path.name == "0000-template.md":
            continue
        body = path.read_text(encoding="utf-8")
        status_match = STATUS_PATTERN.search(body)
        if status_match and status_match.group(1).strip() == "Proposed":
            errors.append(f"{path.relative_to(root)}: still Proposed at exit review")

    return errors


def validate_repository(root: Path, *, exit_review: bool = False) -> list[str]:
    """Validate the repository contract and return all discovered errors."""
    errors: list[str] = []

    for relative_path in REQUIRED_PATHS:
        if not (root / relative_path).exists():
            errors.append(f"missing required path: {relative_path}")

    for relative_path in FORBIDDEN_PHASE0_DIRECTORIES:
        if (root / relative_path).exists():
            errors.append(f"Phase 0 forbidden directory exists: {relative_path}")

    for path in sorted(root.rglob("*.md")):
        if any(part in IGNORED_DIRECTORY_NAMES for part in path.parts):
            continue
        errors.extend(markdown_errors(path, root))

    if (root / "docs/adr/README.md").exists():
        errors.extend(adr_errors(root))
    if (root / "docs/security/threat-model.md").exists():
        errors.extend(threat_model_errors(root))
    if exit_review:
        errors.extend(exit_review_errors(root))

    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--exit-review",
        action="store_true",
        help="also reject unresolved owners, targets, dates, and Proposed ADRs",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = repository_root()
    errors = validate_repository(root, exit_review=args.exit_review)

    if errors:
        print("Phase 0 repository validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    mode = "exit-review" if args.exit_review else "working"
    print(f"Phase 0 repository validation passed ({mode} mode).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
