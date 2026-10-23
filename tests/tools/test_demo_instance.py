"""Startup context and selection for the actual local institution viewer."""

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
spec = importlib.util.spec_from_file_location("demo_instance", ROOT / "tools/demo_instance.py")
assert spec and spec.loader
instance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(instance)


@pytest.mark.parametrize("slug", instance.PROFILES)
def test_each_institution_is_selectable_and_pinned(slug):
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools/demo_instance.py"), "--institution", slug],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )
    directory = Path(result.stdout.strip())
    context = json.loads((directory / "instance.json").read_text())
    pack = json.loads((directory / "packs" / f"{slug}.json").read_text())
    assert context["selected_pack_id"] == slug
    assert context["selected_tenant_id"] == pack["tenant_id"]
    assert context["database_imported"] is False
    assert len(list((directory / "packs").glob("*.json"))) == 4


def test_missing_or_unknown_selection_fails_without_silent_default(monkeypatch):
    monkeypatch.setattr(sys.stdin, "isatty", lambda: False)
    with pytest.raises(ValueError, match="Choose an institution"):
        instance.select_institution(None)
    with pytest.raises(ValueError, match="Unknown institution"):
        instance.select_institution("../../some-other-file")


def test_terminal_menu_can_select_an_institution(monkeypatch, capsys):
    monkeypatch.setattr(sys.stdin, "isatty", lambda: True)
    monkeypatch.setattr("builtins.input", lambda: "3")
    assert instance.select_institution(None) == "hong-kong-kindergarten"
    assert "Harbour Lantern" in capsys.readouterr().err
