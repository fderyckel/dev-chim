"""Contract checks for distributable fixtures and their local preparation boundary."""

import copy
import hashlib
import importlib.util
import json
import subprocess
import sys
from collections import Counter
from datetime import date
from pathlib import Path
from uuid import uuid4

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
spec = importlib.util.spec_from_file_location("demo_data", ROOT / "tools/demo_data.py")
assert spec and spec.loader
demo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(demo)


@pytest.fixture
def packs():
    return demo.generate()


def test_shipped_catalog_is_reproducible_complete_and_tenant_separated():
    packs = demo.check()
    seen = set()
    assert len(packs) == 4
    for pack in packs.values():
        ids = {r["id"] for rows in pack["records"].values() for r in rows}
        assert not seen.intersection(ids)
        seen.update(ids)
        assert pack["accounts"] == pack["authorization_grants"] == []
        assert len(pack["records"]["applications"]) == 8


@pytest.mark.parametrize("slug", demo.PROFILES)
def test_dates_and_boundary_scenarios_are_present(packs, slug):
    rows = packs[slug]["records"]
    assert any(r["effective_from"] > demo.AS_OF for r in rows["enrolments"])
    assert any(r["effective_until"] < demo.AS_OF for r in rows["enrolments"])
    assert any(r["effective_from"] == "2026-09-14" for r in rows["enrolments"])
    assert {"missing_documents", "deferred", "withdrawn", "accepted_offer"} <= {
        r["status"] for r in rows["applications"]
    }
    names = Counter(r["display_name"] for r in rows["people"])
    assert max(names.values()) >= 2
    assert any(r["effect"] == "no_instruction" for r in rows["closures"])
    assert all(r["instruction_effect"] == "event_only" for r in rows["events"])
    assert all(r["delivery_enabled"] is False for r in rows["events"])


def test_kindergarten_has_plausible_ages_disjoint_sessions_and_support_staff(packs):
    rows = packs["hong-kong-kindergarten"]["records"]
    people = {p["id"]: p for p in rows["people"]}
    for student in rows["students"]:
        born = date.fromisoformat(people[student["person_id"]]["date_of_birth"])
        age = (
            2026 - born.year
        )  # Every fictional birthday precedes the fixed October reference date.
        assert age == {"K1": 3, "K2": 4, "K3": 5}[student["year_level"]]
    assert {r["service_mode"] for r in rows["registers"]} == {"AM", "PM"}
    assert any(s["function"] == "classroom_support" for s in rows["educators"])
    assert not rows["sections"]
    placements = Counter(r["enrolment_id"] for r in rows["placements"])
    assert sorted(placements.values()).count(2) == 1  # The sole transfer is adjacent in time.


def test_college_has_adults_dual_participation_and_overlapping_sections(packs):
    rows = packs["us-community-college"]["records"]
    assert rows["registers"] == rows["placements"] == []
    assert {s["person_id"] for s in rows["students"]} & {s["person_id"] for s in rows["educators"]}
    assert any(s["entry_context"] == "returning_learner" for s in rows["students"])
    assert len(rows["relationships"]) < len(rows["students"])
    for enrolment in rows["enrolments"]:
        registrations = [
            r for r in rows["section_registrations"] if r["enrolment_id"] == enrolment["id"]
        ]
        if any(
            a["section_id"] != b["section_id"]
            and max(a["effective_from"], b["effective_from"])
            < min(a["effective_until"], b["effective_until"])
            for a in registrations
            for b in registrations
        ):
            break
    else:
        pytest.fail("No overlapping course-section example")
    assert all(r["scenario_only"] for r in rows["section_registrations"])
    assert any(e["kind"] == "fictional_add_drop_deadline" for e in rows["events"])


def test_school_families_have_shared_missing_and_ended_contact_examples(packs):
    rows = packs["england-independent"]["records"]
    contacts = Counter(r["contact_person_id"] for r in rows["relationships"])
    assert max(contacts.values()) > 1
    people = {p["id"]: p for p in rows["people"]}
    assert any(people[r["contact_person_id"]]["email"] is None for r in rows["relationships"])
    assert any(r["effective_until"] < demo.AS_OF for r in rows["relationships"])
    assert {r["mode"] for r in rows["boarding_contexts"]} == {"day", "boarding"}
    assert any(e["kind"] == "boarding_movement" for e in rows["events"])


@pytest.mark.parametrize("slug", ["bangkok-international", "england-independent"])
def test_subject_transfer_preserves_register_and_school_sections_have_single_year(packs, slug):
    rows = packs[slug]["records"]
    sections = {s["id"]: s for s in rows["sections"]}
    enrolments = {e["id"]: e for e in rows["enrolments"]}
    students = {s["id"]: s for s in rows["students"]}
    for registration in rows["section_registrations"]:
        enrolment = enrolments[registration["enrolment_id"]]
        assert (
            students[enrolment["student_id"]]["year_level"]
            == sections[registration["section_id"]]["year_level"]
        )
    changed = next(
        r
        for r in rows["section_registrations"]
        if r.get("scenario_key") == "subject_change_preserving_register"
    )
    placements = [p for p in rows["placements"] if p["enrolment_id"] == changed["enrolment_id"]]
    assert len(placements) == 1
    assert (
        placements[0]["effective_from"]
        < changed["effective_from"]
        < placements[0]["effective_until"]
    )
    original = next(
        r
        for r in rows["section_registrations"]
        if r["enrolment_id"] == changed["enrolment_id"]
        and r["effective_until"] == changed["effective_from"]
        and sections[r["section_id"]]["subject"] == sections[changed["section_id"]]["subject"]
    )
    assert (
        sections[original["section_id"]]["year_level"]
        == sections[changed["section_id"]]["year_level"]
    )


def test_senior_pathways_and_college_audience_language(packs):
    rows = packs["bangkok-international"]["records"]
    students = {s["id"]: s for s in rows["students"]}
    programmes = {p["id"]: p for p in rows["programmes"]}
    for enrolment in rows["enrolments"]:
        if programmes[enrolment["programme_id"]]["label"] == "IB Diploma":
            assert students[enrolment["student_id"]]["year_level"] in {"Grade 11", "Grade 12"}
    assert all(
        "famil" not in e["audience"] and e["kind"] != "family_conference"
        for e in packs["us-community-college"]["records"]["events"]
    )


@pytest.mark.parametrize(
    "damage,match",
    [
        ("tenant", "cross-tenant"),
        ("reference", "unresolved"),
        ("overlap", "overlapping"),
        ("email", "non-demo contact"),
        ("authority", "authority"),
        ("applicant", "silently enrolled"),
        ("period", "overlapping primary"),
        ("child_interval", "dated child outside"),
    ],
)
def test_invalid_pack_fails_closed(packs, damage, match):
    pack = copy.deepcopy(packs["england-independent"])
    rows = pack["records"]
    if damage == "tenant":
        rows["people"][0]["tenant_id"] = packs["hong-kong-kindergarten"]["tenant_id"]
    elif damage == "reference":
        rows["enrolments"][0]["student_id"] = packs["hong-kong-kindergarten"]["records"][
            "students"
        ][0]["id"]
    elif damage == "overlap":
        extra = {**rows["placements"][0], "id": str(uuid4())}
        rows["placements"].append(extra)
    elif damage == "email":
        rows["people"][0]["email"] = "person@school.edu"
    elif damage == "authority":
        rows["relationships"][0]["disclosure_authority"] = True
    elif damage == "applicant":
        rows["applications"][0]["person_id"] = rows["students"][0]["person_id"]
    elif damage == "period":
        rows["periods"][1]["start_on"] = rows["periods"][0]["end_on"]
    elif damage == "child_interval":
        rows["placements"][0]["effective_until"] = "2028-01-01"
    with pytest.raises(ValueError, match=match):
        demo.validate(pack)


def test_prepare_copies_all_packs_with_hashes_and_preserves_existing_instance(tmp_path):
    destination = tmp_path / "instance"
    demo.prepare(destination, "local-synthetic")
    manifest = json.loads((destination / "manifest.json").read_text())
    assert len(manifest["packs"]) == 4
    for pack in manifest["packs"]:
        assert (
            hashlib.sha256((destination / pack["path"]).read_bytes()).hexdigest() == pack["sha256"]
        )
    info = json.loads((destination / "instance.json").read_text())
    assert info["database_imported"] is False
    sentinel = destination / "my-review.txt"
    sentinel.write_text("keep this")
    with pytest.raises(FileExistsError):
        demo.prepare(destination, "local-synthetic")
    assert sentinel.read_text() == "keep this"


def test_prepare_rejects_production_and_corrupt_sources_before_creating_destination(
    tmp_path, monkeypatch
):
    destination = tmp_path / "instance"
    with pytest.raises(ValueError, match="local-synthetic"):
        demo.prepare(destination, "production")
    assert not destination.exists()

    def corrupted():
        raise ValueError("fixture drift")

    monkeypatch.setattr(demo, "check", corrupted)
    with pytest.raises(ValueError, match="fixture drift"):
        demo.prepare(destination, "local-synthetic")
    assert not destination.exists()


def test_launcher_prepares_all_packs_and_passes_directory_to_child():
    result = subprocess.run(
        [str(ROOT / "bin/with-demo-data"), "printenv", "CHIMWEMWE_DEMO_DATA_DIRECTORY"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )
    directory = Path(result.stdout.strip().splitlines()[-1])
    assert directory.is_relative_to(ROOT / "tmp" / "demo-instances")
    assert {p.stem for p in (directory / "packs").glob("*.json")} == set(demo.PROFILES)


def test_standard_local_entry_points_prepare_catalog():
    result = subprocess.run(
        ["make", "-n", "auth-demo", "legal-demo", "classroom-demo", "web-dev", "web-core-dev"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )
    assert result.stdout.count("bin/with-demo-data") == 5
