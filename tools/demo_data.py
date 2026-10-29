"""Build, verify and prepare inert fictional demo packs. Never connects to a database."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import tempfile
from datetime import date, timedelta
from itertools import pairwise
from pathlib import Path
from uuid import NAMESPACE_URL, UUID, uuid5
from zoneinfo import ZoneInfo

from demo_data_profiles import PROFILES

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "demo-data"
VERSION = 1
AS_OF = "2026-10-23"
TABLES = (
    "institutions",
    "units",
    "sites",
    "programmes",
    "academic_years",
    "periods",
    "closures",
    "events",
    "people",
    "students",
    "educators",
    "relationships",
    "enrolments",
    "registers",
    "placements",
    "teaching_assignments",
    "calendar_sessions",
    "sections",
    "section_registrations",
    "applications",
    "boarding_contexts",
    "activities",
    "activity_memberships",
)
REFERENCES = {
    "institution_id": "institutions",
    "unit_id": "units",
    "site_id": "sites",
    "programme_id": "programmes",
    "academic_year_id": "academic_years",
    "period_id": "periods",
    "person_id": "people",
    "student_id": "students",
    "educator_id": "educators",
    "contact_person_id": "people",
    "enrolment_id": "enrolments",
    "register_id": "registers",
    "calendar_session_id": "calendar_sessions",
    "section_id": "sections",
    "activity_id": "activities",
}


def encoded(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def digest(content: str) -> str:
    return hashlib.sha256(content.encode()).hexdigest()


def next_day(value: str) -> str:
    return (date.fromisoformat(value) + timedelta(days=1)).isoformat()


def stage(level: str) -> int:
    if level.startswith("Year "):
        number = int(level.split()[-1])
        return 0 if number < 9 else 1 if number < 12 else 2
    if level.startswith("Grade "):
        number = int(level.split()[-1])
        return 0 if number < 6 else 1 if number < 9 else 2
    return 0


class Builder:
    def __init__(self, slug: str):
        self.slug = slug
        self.profile = PROFILES[slug]
        self.tenant_id = str(uuid5(NAMESPACE_URL, f"chimwemwe:demo:v{VERSION}:{slug}"))
        self.rows: dict[str, list[dict]] = {table: [] for table in TABLES}

    def add(self, table: str, key: str, **fields) -> dict:
        row = {
            "id": str(uuid5(UUID(self.tenant_id), f"{table}:{key}")),
            "tenant_id": self.tenant_id,
            **fields,
        }
        self.rows[table].append(row)
        return row

    def person(self, key: str, index: int, age: int, *, contact: bool = True) -> dict:
        p = self.profile
        given = p["given_names"][index % len(p["given_names"])]
        family = p["family_names"][(index // len(p["given_names"])) % len(p["family_names"])]
        # Fictional birthdays make the declared age exact at the fixed reference date.
        born = date(2026 - age, 1 + index % 9, 1 + index % 27)
        return self.add(
            "people",
            key,
            display_name=f"{given} {family}",
            fictional=True,
            date_of_birth=born.isoformat(),
            preferred_language=p["languages"][index % len(p["languages"])],
            email=f"{key}@{self.slug}.example.test" if contact else None,
        )

    def build(self) -> dict:
        p = self.profile
        college = p["kind"] == "community_college"
        kindergarten = p["kind"] == "kindergarten"
        institution = self.add(
            "institutions",
            "root",
            name=p["name"],
            kind=p["kind"],
            city=p["city"],
            country=p["country"],
            locale=p["locale"],
            fictional=True,
        )
        iid = institution["id"]
        site = self.add("sites", "main", institution_id=iid, label="Demo main campus")
        units = [
            self.add("units", str(n), institution_id=iid, label=label)
            for n, label in enumerate(p["divisions"])
        ]
        programmes = [
            self.add("programmes", str(n), institution_id=iid, label=label)
            for n, label in enumerate(p["programmes"])
        ]
        year = self.add(
            "academic_years",
            "2026-27",
            institution_id=iid,
            label="2026-2027 (Demo)",
            start_on="2026-08-01",
            end_on="2027-07-31",
            time_zone=p["time_zone"],
            instructional_weekdays=[1, 2, 3, 4, 5],
            date_basis="fictional_fixed_example",
        )
        yid = year["id"]
        for n, (label, start, end) in enumerate(p["periods"]):
            self.add(
                "periods",
                str(n),
                academic_year_id=yid,
                sequence=n + 1,
                label=label,
                start_on=start,
                end_on=end,
            )
        for n, (label, start, end) in enumerate(p["closures"]):
            self.add(
                "closures",
                str(n),
                academic_year_id=yid,
                label=label,
                start_on=start,
                end_on=end,
                scope="all_students",
                effect="no_instruction",
            )
        start = p["periods"][0][1]
        until = next_day(p["periods"][-1][2])
        self.add(
            "closures",
            "staff-development",
            academic_year_id=yid,
            label="Demo student closure for staff development",
            start_on="2026-11-20",
            end_on="2026-11-20",
            scope="all_students",
            effect="no_instruction",
        )
        for n, (kind, label, on, effect, audience) in enumerate(
            [
                (
                    "staff_preparation",
                    "Demo staff preparation",
                    (date.fromisoformat(start) - timedelta(days=3)).isoformat(),
                    "event_only",
                    "staff",
                ),
                (
                    "orientation",
                    "Demo new learner welcome",
                    (date.fromisoformat(start) - timedelta(days=2)).isoformat(),
                    "event_only",
                    "new_learners",
                ),
                (
                    "learner_advising" if college else "family_conference",
                    "Demo learner advising" if college else "Demo learning conversations",
                    "2026-11-12",
                    "event_only",
                    "participating_learners" if college else "invited_families",
                ),
                (
                    "staff_development",
                    "Demo staff learning day",
                    "2026-11-20",
                    "event_only",
                    "staff",
                ),
            ]
        ):
            self.add(
                "events",
                str(n),
                academic_year_id=yid,
                site_id=site["id"],
                kind=kind,
                label=label,
                on=on,
                instruction_effect=effect,
                audience=audience,
                delivery_enabled=False,
            )

        staff = []
        for n in range(p["staff_count"]):
            person = self.person(f"staff-{n:03}", n + 16, 27 + n % 25)
            staff.append(
                self.add(
                    "educators",
                    str(n),
                    person_id=person["id"],
                    institution_id=iid,
                    function="classroom_support"
                    if kindergarten and n % 3 == 2
                    else "instructor"
                    if college
                    else "educator",
                    effective_from=start,
                    effective_until=until,
                )
            )

        groups = []
        for level, age in p["levels"]:
            sessions = ["AM", "PM"] if kindergarten else ["day"]
            for session in sessions:
                unit = units[stage(level)] if not college else units[0]
                if not college:
                    groups.append(
                        (
                            self.add(
                                "registers",
                                f"{level}-{session}",
                                institution_id=iid,
                                unit_id=unit["id"],
                                site_id=site["id"],
                                academic_year_id=yid,
                                label=f"{level} {session}",
                                year_level=level,
                                service_mode=session,
                                meaning="daily_register",
                            ),
                            age,
                        )
                    )

        count = p.get("student_count", len(groups) * p.get("class_size", 0))
        students = []
        enrolments = []
        for n in range(count):
            group, age = (
                (None, [18, 19, 21, 24, 32, 45, 58][n % 7])
                if college
                else groups[n // p["class_size"]]
            )
            person = self.person(f"student-{n:03}", n, age, contact=college or age >= 11)
            # Two genuinely distinct identities intentionally share a display name.
            if n == 1:
                person["display_name"] = self.rows["people"][p["staff_count"]]["display_name"]
            student = self.add(
                "students",
                str(n),
                person_id=person["id"],
                institution_id=iid,
                year_level="College" if college else group["year_level"],
                study_intention="part_time" if college and n % 3 == 0 else "full_time",
                entry_context="returning_learner" if college and n % 7 == 4 else "continuing",
                effective_from=start,
                effective_until=until,
            )
            students.append(student)
            begins = "2026-11-02" if n == 2 else "2026-09-14" if n == 4 else start
            ends = "2026-10-15" if n == 3 else until
            programme = n % len(programmes) if college else stage(student["year_level"])
            if p["kind"] == "international_school" and student["year_level"] in [
                "Grade 11",
                "Grade 12",
            ]:
                programme = 2 + n % 3
            enrolment = self.add(
                "enrolments",
                str(n),
                student_id=student["id"],
                academic_year_id=yid,
                programme_id=programmes[programme]["id"],
                effective_from=begins,
                effective_until=ends,
            )
            enrolments.append(enrolment)
            if group:
                self.add(
                    "placements",
                    str(n),
                    enrolment_id=enrolment["id"],
                    register_id=group["id"],
                    effective_from=begins,
                    effective_until=ends,
                )
            if not college:
                # Siblings share a family contact; surnames intentionally need not match.
                family = n // 2
                contact_key = f"family-{family:03}"
                if n % 2 == 0:
                    guardian = self.person(
                        contact_key, family + 32, 31 + family % 20, contact=family != 2
                    )
                    guardian["email"] = (
                        "shared-family@example.test" if family < 2 else guardian["email"]
                    )
                else:
                    guardian = next(
                        r
                        for r in self.rows["people"]
                        if r["id"] == str(uuid5(UUID(self.tenant_id), f"people:{contact_key}"))
                    )
                self.relationship(student, guardian, "parent", start, until, "family_contact")
                if n % 4 == 0:
                    other = self.person(f"second-contact-{n:03}", n + 48, 34 + n % 19)
                    self.relationship(student, other, "guardian", start, until, "family_contact")
            elif n % 12 == 0:
                contact = self.person(f"optional-contact-{n:03}", n + 48, 35)
                self.relationship(
                    student, contact, "nominated_contact", start, until, "emergency_contact_example"
                )

        # A staff person may independently be a guardian or learner without extra access.
        staff_person = self.rows["people"][0]
        if college:
            dual = self.add(
                "students",
                "staff-learner",
                person_id=staff_person["id"],
                institution_id=iid,
                year_level="College",
                study_intention="part_time",
                entry_context="staff_and_learner",
                effective_from=start,
                effective_until=until,
            )
            students.append(dual)
            enrolments.append(
                self.add(
                    "enrolments",
                    "staff-learner",
                    student_id=dual["id"],
                    academic_year_id=yid,
                    programme_id=programmes[2]["id"],
                    effective_from=start,
                    effective_until=until,
                )
            )
        else:
            self.relationship(students[4], staff_person, "guardian", start, until, "family_contact")
            self.relationship(
                students[5],
                staff_person,
                "former_contact",
                start,
                "2026-10-01",
                "historical_relationship_only",
            )

        for n, (group, _age) in enumerate(groups):
            self.add(
                "teaching_assignments",
                str(n),
                educator_id=staff[n % len(staff)]["id"],
                register_id=group["id"],
                responsibility="daily_register",
                effective_from=start,
                effective_until=until,
            )
        if groups:
            # Adjacent same-level placements demonstrate a transfer without concurrent registers.
            first = self.rows["placements"][0]
            first["effective_until"] = "2026-10-12"
            alternate = self.add(
                "registers",
                "transfer",
                **{k: v for k, v in groups[0][0].items() if k not in {"id", "tenant_id", "label"}},
                label=groups[0][0]["label"] + " B",
            )
            self.add(
                "placements",
                "transfer",
                enrolment_id=enrolments[0]["id"],
                register_id=alternate["id"],
                effective_from="2026-10-12",
                effective_until=until,
            )
            self.add(
                "teaching_assignments",
                "substitute",
                educator_id=staff[-1]["id"],
                register_id=alternate["id"],
                responsibility="substitute",
                effective_from=start,
                effective_until="2026-10-12",
            )
            self.add(
                "teaching_assignments",
                "replacement",
                educator_id=staff[-2]["id"],
                register_id=alternate["id"],
                responsibility="daily_register",
                effective_from="2026-10-12",
                effective_until=until,
            )

        self.subjects(students, enrolments, staff, year)
        for n, status in enumerate(
            [
                "enquiry",
                "submitted",
                "missing_documents",
                "offered",
                "accepted_offer",
                "deferred",
                "withdrawn",
                "waitlisted",
            ]
        ):
            programme = n % len(programmes)
            entry_levels = (
                [("College", 18)] * len(programmes)
                if college
                else [
                    ("Pre-K", 4),
                    ("Grade 6", 11),
                    ("Grade 9", 14),
                    ("Grade 11", 16),
                    ("Grade 11", 16),
                ]
                if p["kind"] == "international_school"
                else [("Year 7", 11), ("Year 9", 13), ("Year 12", 16)]
                if p["kind"] == "independent_school"
                else [("K1", 3)]
            )
            entry_level, entry_age = entry_levels[programme]
            person = self.person(f"applicant-{n:03}", n + 8, entry_age, contact=college)
            person["date_of_birth"] = date(2027 - entry_age, 1 + n % 6, 1 + n % 20).isoformat()
            self.add(
                "applications",
                str(n),
                person_id=person["id"],
                institution_id=iid,
                programme_id=programmes[programme]["id"],
                status=status,
                intended_entry_on="2027-08-23",
                target_year_level=entry_level,
                creates_enrolment=False,
                grants_access=False,
            )

        if p["kind"] == "independent_school":
            for n, student in enumerate(students):
                self.add(
                    "boarding_contexts",
                    str(n),
                    student_id=student["id"],
                    mode="boarding" if n % 3 == 0 else "day",
                    effective_from=start,
                    effective_until=until,
                    grants_access=False,
                )
            self.add(
                "events",
                "boarder-return",
                academic_year_id=yid,
                site_id=site["id"],
                kind="boarding_movement",
                label="Demo boarder return",
                on="2026-11-01",
                audience="boarders_only",
                instruction_effect="event_only",
                delivery_enabled=False,
            )
        if kindergarten:
            self.add(
                "events",
                "play",
                academic_year_id=yid,
                site_id=site["id"],
                kind="play_block",
                label="Demo shared story and outdoor play",
                on="2026-11-05",
                audience="K1_AM",
                instruction_effect="event_only",
                delivery_enabled=False,
            )

        activity = self.add(
            "activities",
            "creative",
            institution_id=iid,
            site_id=site["id"],
            label="Demo creative play" if kindergarten else "Demo community arts",
            meaning="mixed_group_activity",
            grants_access=False,
        )
        for n, student in enumerate(students[::12]):
            self.add(
                "activity_memberships",
                str(n),
                activity_id=activity["id"],
                student_id=student["id"],
                effective_from=start,
                effective_until=until,
            )

        return {
            "schema_version": VERSION,
            "pack_id": self.slug,
            "tenant_id": self.tenant_id,
            "synthetic": True,
            "reference_date": AS_OF,
            "source_ids": p["sources"],
            "usage": "local_synthetic_scenarios_only",
            "accounts": [],
            "authorization_grants": [],
            "date_conventions": {
                "calendar": "inclusive_start_and_end",
                "relationships_and_participation": "half_open_from_until",
            },
            "runtime_import": "none; prepare copies files only",
            "assumptions": [
                "All identities, contacts, counts, events and policies are fictional.",
                "Dates are fixed 2026-27 examples; no current date or historical record is implied.",
                "Contact, relationship, programme and section data grant no account or authority.",
                "No whole-day session placement, lesson attendance or course-registration support is implied.",
                "K1/K2/K3 comes from the EDB pattern; ESF inspiration covers play/inquiry, not a K3 claim.",
                "Mon-Fri is a fictional demo choice, not a source-school week or holiday-policy replica.",
            ],
            "records": self.rows,
        }

    def relationship(self, student, person, meaning, start, until, purpose):
        self.add(
            "relationships",
            str(len(self.rows["relationships"])),
            student_id=student["id"],
            contact_person_id=person["id"],
            meaning=meaning,
            purpose=purpose,
            effective_from=start,
            effective_until=until,
            account_access=False,
            disclosure_authority=False,
            collection_authority=False,
            notice_recipient=False,
        )

    def subjects(self, students, enrolments, staff, year):
        p = self.profile
        if p["kind"] == "kindergarten":
            return
        college = p["kind"] == "community_college"
        periods = self.rows["periods"]
        sessions = []
        specs = (
            [
                (0, "Full fall", "2026-08-31", "2026-12-22"),
                (0, "First eight weeks", "2026-08-31", "2026-10-25"),
                (0, "Second eight weeks", "2026-10-26", "2026-12-20"),
                (0, "Twelve weeks", "2026-09-21", "2026-12-13"),
                (1, "Winter short session", "2027-01-04", "2027-02-11"),
                (2, "Full spring", "2027-02-16", "2027-06-15"),
                (3, "Summer short session", "2027-06-21", "2027-07-30"),
            ]
            if college
            else [(0, "Subject teaching", periods[0]["start_on"], periods[0]["end_on"])]
        )
        for n, (period, label, start, end) in enumerate(specs):
            session = self.add(
                "calendar_sessions",
                str(n),
                academic_year_id=year["id"],
                period_id=periods[period]["id"],
                label=label,
                start_on=start,
                end_on=end,
            )
            sessions.append(session)
            if college:
                self.add(
                    "events",
                    f"deadline-{n}",
                    academic_year_id=year["id"],
                    calendar_session_id=session["id"],
                    kind="fictional_add_drop_deadline",
                    label="Demo session add/drop deadline",
                    on=(date.fromisoformat(start) + timedelta(days=7)).isoformat(),
                    audience="this_session_only",
                    instruction_effect="event_only",
                    delivery_enabled=False,
                )
        if not college:
            self.school_subjects(students, enrolments, staff, year, sessions[0])
            return
        subjects = ["Academic writing", "Mathematics", "Environmental science", "Digital media"]
        for n in range(12):
            session = sessions[n % len(sessions)]
            section = self.add(
                "sections",
                str(n),
                academic_year_id=year["id"],
                calendar_session_id=session["id"],
                educator_id=staff[n % 4]["id"],
                label=f"{subjects[n % 4]} {n + 1:02}",
                meaning="course_section",
                delivery="evening" if n % 2 else "daytime",
                start_on=session["start_on"],
                end_on=session["end_on"],
                scenario_only=True,
            )
            for i, _student in enumerate(students):
                if (i + n) % 3 != 0:
                    continue
                enrolment = enrolments[i]
                begins = max(section["start_on"], enrolment["effective_from"])
                ends = min(next_day(section["end_on"]), enrolment["effective_until"])
                if begins < ends:
                    self.add(
                        "section_registrations",
                        f"{n}-{i}",
                        section_id=section["id"],
                        enrolment_id=enrolment["id"],
                        effective_from=begins,
                        effective_until=ends,
                        scenario_only=True,
                    )

    def school_subjects(self, students, enrolments, staff, year, session):
        levels = [
            level
            for level, _age in self.profile["levels"]
            if level.startswith(("Grade ", "Year ")) and int(level.split()[-1]) >= 6
        ]
        for level_number, level in enumerate(levels):
            for subject_number, subject in enumerate(["English", "Mathematics", "Science", "Arts"]):
                section = self.add(
                    "sections",
                    f"{level}-{subject}",
                    academic_year_id=year["id"],
                    calendar_session_id=session["id"],
                    educator_id=staff[subject_number]["id"],
                    label=f"{level} {subject} A",
                    subject=subject,
                    year_level=level,
                    meaning="subject_group",
                    delivery="daytime",
                    start_on=session["start_on"],
                    end_on=session["end_on"],
                    scenario_only=True,
                )
                for i, student in enumerate(students):
                    if student["year_level"] != level:
                        continue
                    enrolment = enrolments[i]
                    begins = max(session["start_on"], enrolment["effective_from"])
                    ends = min(next_day(session["end_on"]), enrolment["effective_until"])
                    if begins >= ends:
                        continue
                    registration = self.add(
                        "section_registrations",
                        f"{level}-{subject}-{i}",
                        section_id=section["id"],
                        enrolment_id=enrolment["id"],
                        effective_from=begins,
                        effective_until=ends,
                        scenario_only=True,
                    )
                    cohort_indices = [j for j, s in enumerate(students) if s["year_level"] == level]
                    if level_number == 0 and subject_number == 0 and i == cohort_indices[6]:
                        registration["effective_until"] = "2026-10-12"
                        alternate = self.add(
                            "sections",
                            "subject-change",
                            **{
                                k: v
                                for k, v in section.items()
                                if k not in {"id", "tenant_id", "label"}
                            },
                            label=f"{level} {subject} B",
                        )
                        self.add(
                            "section_registrations",
                            "subject-change",
                            section_id=alternate["id"],
                            enrolment_id=enrolment["id"],
                            effective_from="2026-10-12",
                            effective_until=ends,
                            scenario_only=True,
                            scenario_key="subject_change_preserving_register",
                        )


def generate() -> dict[str, dict]:
    return {slug: Builder(slug).build() for slug in PROFILES}


def validate(pack: dict) -> None:
    """Reject invalid relationships before preparing any instance files."""

    def require(condition, message):
        if not condition:
            raise ValueError(f"{pack.get('pack_id', 'unknown')}: {message}")

    require(
        pack["schema_version"] == VERSION and pack["synthetic"] is True, "synthetic schema required"
    )
    require(pack["pack_id"] in PROFILES, "unknown pack")
    require(pack["tenant_id"] == Builder(pack["pack_id"]).tenant_id, "wrong pack tenant")
    require(
        pack["accounts"] == [] and pack["authorization_grants"] == [], "authority is prohibited"
    )
    require(pack["usage"] == "local_synthetic_scenarios_only", "local scope required")
    rows = pack["records"]
    require(set(rows) == set(TABLES), "unexpected or missing record tables")
    index = {table: {r["id"]: r for r in items} for table, items in rows.items()}
    ids = [r["id"] for items in rows.values() for r in items]
    require(len(ids) == len(set(ids)), "duplicate identities")
    for items in rows.values():
        for row in items:
            UUID(row["id"])
            require(row["tenant_id"] == pack["tenant_id"], "cross-tenant record")
            for key, target in REFERENCES.items():
                if key in row:
                    require(row[key] in index[target], f"unresolved {key}")
            if "effective_from" in row:
                require(
                    date.fromisoformat(row["effective_from"])
                    < date.fromisoformat(row["effective_until"]),
                    "empty interval",
                )
            if "start_on" in row:
                require(
                    date.fromisoformat(row["start_on"]) <= date.fromisoformat(row["end_on"]),
                    "reversed dates",
                )
    for person in rows["people"]:
        require(person["fictional"] is True, "fictional identity marker required")
        email = person["email"]
        domain = email.rsplit("@", 1)[-1] if email else ""
        require(
            email is None
            or (
                email.count("@") == 1
                and (domain == "example.test" or domain.endswith(".example.test"))
            ),
            "non-demo contact",
        )
        require(
            date.fromisoformat(person["date_of_birth"]) < date.fromisoformat(AS_OF),
            "invalid birthday",
        )
    for year in rows["academic_years"]:
        ZoneInfo(year["time_zone"])
        require(set(year["instructional_weekdays"]) <= set(range(1, 8)), "invalid weekdays")
        periods = sorted(
            (p for p in rows["periods"] if p["academic_year_id"] == year["id"]),
            key=lambda p: p["sequence"],
        )
        require(
            [p["sequence"] for p in periods] == list(range(1, len(periods) + 1)), "period sequence"
        )
        for n, period in enumerate(periods):
            require(
                year["start_on"] <= period["start_on"] <= period["end_on"] <= year["end_on"],
                "period outside year",
            )
            require(
                n == 0 or periods[n - 1]["end_on"] < period["start_on"],
                "overlapping primary periods",
            )
    for table in ["closures", "calendar_sessions"]:
        for row in rows[table]:
            parent = (
                index["periods"][row["period_id"]]
                if table == "calendar_sessions"
                else index["academic_years"][row["academic_year_id"]]
            )
            require(
                parent["start_on"] <= row["start_on"] <= row["end_on"] <= parent["end_on"],
                "calendar child outside parent",
            )
    for relation in rows["relationships"]:
        require(
            all(
                relation[key] is False
                for key in [
                    "account_access",
                    "disclosure_authority",
                    "collection_authority",
                    "notice_recipient",
                ]
            ),
            "relationship grants authority",
        )
    for application in rows["applications"]:
        require(
            application["creates_enrolment"] is False and application["grants_access"] is False,
            "application grants enrolment or access",
        )
        require(
            application["person_id"] not in {s["person_id"] for s in rows["students"]},
            "applicant silently enrolled",
        )
        born = date.fromisoformat(index["people"][application["person_id"]]["date_of_birth"])
        entry = date.fromisoformat(application["intended_entry_on"])
        age = entry.year - born.year - ((entry.month, entry.day) < (born.month, born.day))
        level = application["target_year_level"]
        expected_age = (
            18
            if level == "College"
            else 3
            if level == "K1"
            else 4
            if level == "Pre-K"
            else int(level.split()[-1]) + (4 if level.startswith("Year ") else 5)
        )
        require(age == expected_age, "applicant age inconsistent with demo entry level")
    for enrolment in rows["enrolments"]:
        student = index["students"][enrolment["student_id"]]
        year = index["academic_years"][enrolment["academic_year_id"]]
        require(
            student["institution_id"] == year["institution_id"], "enrolment institution mismatch"
        )
        require(
            year["start_on"]
            <= enrolment["effective_from"]
            < enrolment["effective_until"]
            <= next_day(year["end_on"]),
            "enrolment outside year",
        )
        require(
            student["effective_from"]
            <= enrolment["effective_from"]
            < enrolment["effective_until"]
            <= student["effective_until"],
            "enrolment outside participation",
        )
    for table, parent_table, parent_key in [
        ("placements", "enrolments", "enrolment_id"),
        ("teaching_assignments", "educators", "educator_id"),
        ("section_registrations", "enrolments", "enrolment_id"),
    ]:
        grouped: dict[str, list[dict]] = {}
        for row in rows[table]:
            parent = index[parent_table][row[parent_key]]
            require(
                parent["effective_from"]
                <= row["effective_from"]
                < row["effective_until"]
                <= parent["effective_until"],
                "dated child outside parent",
            )
            if table == "placements":
                register = index["registers"][row["register_id"]]
                require(
                    parent["academic_year_id"] == register["academic_year_id"],
                    "placement year mismatch",
                )
                grouped.setdefault(row[parent_key], []).append(row)
            elif table == "section_registrations":
                section = index["sections"][row["section_id"]]
                require(
                    parent["academic_year_id"] == section["academic_year_id"],
                    "section year mismatch",
                )
                require(
                    section["start_on"]
                    <= row["effective_from"]
                    < row["effective_until"]
                    <= next_day(section["end_on"]),
                    "registration outside section",
                )
                if section["meaning"] == "subject_group":
                    require(
                        index["students"][parent["student_id"]]["year_level"]
                        == section["year_level"],
                        "subject year-level mismatch",
                    )
        for placements in grouped.values():
            ordered = sorted(placements, key=lambda r: r["effective_from"])
            require(
                all(a["effective_until"] <= b["effective_from"] for a, b in pairwise(ordered)),
                "overlapping register placements",
            )
    for section in rows["sections"]:
        session = index["calendar_sessions"][section["calendar_session_id"]]
        require(
            section["academic_year_id"] == session["academic_year_id"],
            "section session year mismatch",
        )
        require(
            session["start_on"] <= section["start_on"] <= section["end_on"] <= session["end_on"],
            "section outside session",
        )
    if pack["pack_id"] == "us-community-college":
        require(
            not rows["registers"] and not rows["placements"],
            "college section mapped to daily register",
        )


def manifest(packs: dict[str, dict]) -> dict:
    return {
        "schema_version": VERSION,
        "synthetic": True,
        "reference_date": AS_OF,
        "sources_sha256": digest((DATA / "sources.json").read_text()),
        "packs": [
            {
                "pack_id": slug,
                "path": f"packs/{slug}.json",
                "sha256": digest(encoded(pack)),
                "counts": {k: len(v) for k, v in pack["records"].items()},
            }
            for slug, pack in packs.items()
        ],
    }


def check() -> dict[str, dict]:
    packs = generate()
    sources = json.loads((DATA / "sources.json").read_text())
    for slug, pack in packs.items():
        validate(pack)
        if not set(pack["source_ids"]) <= set(sources["sources"]):
            raise ValueError(f"{slug}: missing public-source provenance")
        if (DATA / "packs" / f"{slug}.json").read_text() != encoded(pack):
            raise ValueError(f"{slug}: fixture drift; run make demo-data-build")
    if (DATA / "manifest.json").read_text() != encoded(manifest(packs)):
        raise ValueError("manifest drift; run make demo-data-build")
    return packs


def prepare(destination: Path | None, environment: str) -> Path:
    if environment != "local-synthetic":
        raise ValueError("demo preparation requires environment local-synthetic")
    packs = check()  # Validate every file before creating anything.
    if destination is None:
        base = ROOT / "tmp" / "demo-instances"
        base.mkdir(parents=True, exist_ok=True)
        target = Path(tempfile.mkdtemp(prefix="instance-", dir=base))
    else:
        target = destination.resolve()
        target.mkdir(parents=True, exist_ok=False)
    (target / "packs").mkdir()
    for slug, pack in packs.items():
        (target / "packs" / f"{slug}.json").write_text(encoded(pack))
    for name in ["manifest.json", "sources.json"]:
        (target / name).write_text((DATA / name).read_text())
    (target / "instance.json").write_text(
        encoded(
            {
                "environment": environment,
                "synthetic": True,
                "catalog_version": VERSION,
                "reference_date": AS_OF,
                "database_imported": False,
                "pack_ids": list(packs),
            }
        )
    )
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("build")
    sub.add_parser("check")
    sub.add_parser("list")
    prep = sub.add_parser("prepare")
    prep.add_argument("--environment", required=True, choices=["local-synthetic"])
    prep.add_argument("--destination", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "build":
            packs = generate()
            (DATA / "packs").mkdir(parents=True, exist_ok=True)
            for slug, pack in packs.items():
                validate(pack)
                (DATA / "packs" / f"{slug}.json").write_text(encoded(pack))
            (DATA / "manifest.json").write_text(encoded(manifest(packs)))
        elif args.command == "prepare":
            print(prepare(args.destination, args.environment))
        else:
            packs = check()
            for slug, pack in packs.items():
                rows = pack["records"]
                print(
                    f"{slug}: {len(rows['students'])} learners, {len(rows['educators'])} staff, "
                    f"{len(rows['relationships'])} contact relationships, {len(rows['applications'])} applicants"
                )
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(f"Demo data: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
