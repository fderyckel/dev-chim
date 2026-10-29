"""Prepare one startup-selected synthetic institution for the local browser app."""

import argparse
import json
import sys

from demo_data import PROFILES, encoded, prepare


def select_institution(value: str | None) -> str:
    if value:
        if value not in PROFILES:
            raise ValueError("Unknown institution. Choose: " + ", ".join(PROFILES))
        return value
    if not sys.stdin.isatty():
        raise ValueError("Choose an institution with make demo DEMO=<pack>: " + ", ".join(PROFILES))
    print("Choose a Chimwemwe demo institution:", file=sys.stderr)
    for number, (slug, profile) in enumerate(PROFILES.items(), 1):
        print(f"  {number}. {profile['name']} - {profile['city']} ({slug})", file=sys.stderr)
    print("Institution [1-4]: ", end="", file=sys.stderr, flush=True)
    answer = input().strip()
    if answer in ["1", "2", "3", "4"]:
        return list(PROFILES)[int(answer) - 1]
    return select_institution(answer) if answer else select_institution("invalid")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--institution")
    args = parser.parse_args()
    try:
        slug = select_institution(args.institution)
        directory = prepare(None, "local-synthetic")
        instance_file = directory / "instance.json"
        instance = json.loads(instance_file.read_text())
        pack = json.loads((directory / "packs" / f"{slug}.json").read_text())
        instance.update(selected_pack_id=slug, selected_tenant_id=pack["tenant_id"])
        instance_file.write_text(encoded(instance))
        print(directory)
    except (ValueError, OSError, EOFError) as error:
        print(f"Demo startup: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
