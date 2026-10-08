defmodule Chimwemwe.AcademicCalendar.ContractTest do
  use ExUnit.Case, async: true

  alias Chimwemwe.AcademicCalendar
  alias Chimwemwe.AcademicCalendar.{Error, Preview, Resolution}
  alias Ecto.UUID

  test "previews two terms, an explicit gap, ordinary weekdays, and a closure" do
    input = valid_input()

    assert {:ok,
            %Preview{
              candidate_revision: revision,
              instructional_date_count: instructional_date_count,
              instructional_dates: instructional_dates
            } = preview} = AcademicCalendar.preview_publication(input)

    assert byte_size(revision) == 64
    assert instructional_date_count == length(instructional_dates)
    assert ~D[2026-09-07] in instructional_dates
    refute ~D[2026-10-15] in instructional_dates
    refute ~D[2026-10-24] in instructional_dates
    refute ~D[2026-12-23] in instructional_dates

    assert {:ok,
            %Resolution{
              academic_period_id: first_period_id,
              status: :instructional,
              reason: :instructional_weekday,
              candidate_revision: ^revision
            }} = AcademicCalendar.resolve_date(preview, ~D[2026-09-07])

    assert first_period_id == hd(input.periods).id

    assert {:ok,
            %Resolution{
              academic_period_id: ^first_period_id,
              closure_reason_key: "public_holiday",
              status: :non_instructional,
              reason: :closure
            }} = AcademicCalendar.resolve_date(preview, ~D[2026-10-15])

    assert {:ok,
            %Resolution{
              academic_period_id: ^first_period_id,
              status: :non_instructional,
              reason: :ordinary_weekday_off
            }} = AcademicCalendar.resolve_date(preview, ~D[2026-10-24])

    assert {:ok,
            %Resolution{
              academic_period_id: nil,
              closure_reason_key: "year_end_break",
              status: :non_instructional,
              reason: :closure
            }} = AcademicCalendar.resolve_date(preview, ~D[2026-12-23])

    assert {:ok,
            %Resolution{
              academic_period_id: nil,
              status: :non_instructional,
              reason: :outside_period
            }} = AcademicCalendar.resolve_date(preview, ~D[2026-12-28])
  end

  test "uses exact calendar identity and permits two calendars over the same dates" do
    input = valid_input()
    another_calendar = %{input | calendar_id: UUID.generate(), academic_year_id: UUID.generate()}

    assert {:ok, first} = AcademicCalendar.preview_publication(input)
    assert {:ok, second} = AcademicCalendar.preview_publication(another_calendar)

    assert first.definition.institutional_unit_id == second.definition.institutional_unit_id
    refute first.definition.calendar_id == second.definition.calendar_id
    refute first.candidate_revision == second.candidate_revision
    assert first.instructional_dates == second.instructional_dates
  end

  test "normalizes harmless ordering without changing the candidate revision" do
    input = valid_input()

    reordered = %{
      input
      | instructional_weekdays: Enum.reverse(input.instructional_weekdays),
        periods: Enum.reverse(input.periods),
        closures: Enum.reverse(input.closures)
    }

    assert {:ok, first} = AcademicCalendar.preview_publication(input)
    assert {:ok, second} = AcademicCalendar.preview_publication(reordered)
    assert first == second
  end

  test "rejects implicit ownership, unrecognized input, and malformed identifiers" do
    input = valid_input()

    assert {:error, %Error{code: :invalid_input, field: :definition}} =
             input
             |> Map.delete(:institutional_unit_id)
             |> AcademicCalendar.preview_publication()

    assert {:error, %Error{code: :invalid_input, field: :definition}} =
             input
             |> Map.put(:tenant_id, UUID.generate())
             |> AcademicCalendar.preview_publication()

    assert {:error, %Error{code: :invalid_input, field: :calendar_id}} =
             input
             |> Map.put(:calendar_id, "selected-calendar")
             |> AcademicCalendar.preview_publication()
  end

  test "rejects invalid year and period boundaries" do
    input = valid_input()

    assert {:error, %Error{code: :invalid_date_range, field: :year}} =
             input
             |> Map.merge(%{start_on: ~D[2027-08-31], end_on: ~D[2026-09-01]})
             |> AcademicCalendar.preview_publication()

    outside_period =
      input.periods
      |> hd()
      |> Map.put(:start_on, ~D[2026-08-31])

    assert {:error, %Error{code: :outside_year, field: :period}} =
             input
             |> Map.put(:periods, [outside_period | tl(input.periods)])
             |> AcademicCalendar.preview_publication()

    [first, second] = input.periods
    overlapping_second = %{second | start_on: first.end_on}

    assert {:error, %Error{code: :overlap, field: :periods}} =
             input
             |> Map.put(:periods, [first, overlapping_second])
             |> AcademicCalendar.preview_publication()
  end

  test "rejects duplicate sequence, closure date, and weekday values" do
    input = valid_input()
    [first, second] = input.periods

    assert {:error, %Error{code: :duplicate, field: :period_sequence}} =
             input
             |> Map.put(:periods, [first, %{second | sequence: first.sequence}])
             |> AcademicCalendar.preview_publication()

    closure = hd(input.closures)

    assert {:error, %Error{code: :duplicate, field: :closure_date}} =
             input
             |> Map.put(:closures, [closure, %{closure | id: UUID.generate()}])
             |> AcademicCalendar.preview_publication()

    assert {:error, %Error{code: :duplicate, field: :instructional_weekdays}} =
             input
             |> Map.put(:instructional_weekdays, [1, 2, 2, 3])
             |> AcademicCalendar.preview_publication()
  end

  test "requires a bounded explicit IANA-shaped time zone and local date" do
    input = valid_input()

    assert {:ok, preview} =
             input
             |> Map.put(:time_zone, "Africa/Blantyre")
             |> AcademicCalendar.preview_publication()

    assert preview.definition.time_zone == "Africa/Blantyre"

    assert {:error, %Error{code: :unsupported_time_zone, field: :time_zone}} =
             input
             |> Map.put(:time_zone, "local")
             |> AcademicCalendar.preview_publication()

    assert {:error, %Error{code: :invalid_input, field: :local_date}} =
             AcademicCalendar.resolve_date(preview, "2026-09-07")

    assert {:error, %Error{code: :not_found, field: :local_date}} =
             AcademicCalendar.resolve_date(preview, ~D[2026-08-31])
  end

  defp valid_input do
    %{
      academic_year_id: "11111111-1111-4111-8111-111111111111",
      calendar_id: "22222222-2222-4222-8222-222222222222",
      institutional_unit_id: "33333333-3333-4333-8333-333333333333",
      code: "AY_2026_27",
      label: "Academic year 2026–2027",
      start_on: ~D[2026-09-01],
      end_on: ~D[2027-06-30],
      time_zone: "Africa/Blantyre",
      instructional_weekdays: [1, 2, 3, 4, 5],
      periods: [
        %{
          id: "44444444-4444-4444-8444-444444444444",
          period_type_key: "term",
          label: "Term 1",
          sequence: 1,
          start_on: ~D[2026-09-01],
          end_on: ~D[2026-12-18]
        },
        %{
          id: "55555555-5555-4555-8555-555555555555",
          period_type_key: "term",
          label: "Term 2",
          sequence: 2,
          start_on: ~D[2027-01-11],
          end_on: ~D[2027-06-30]
        }
      ],
      closures: [
        %{
          id: "66666666-6666-4666-8666-666666666666",
          date: ~D[2026-10-15],
          reason_key: "public_holiday",
          label: "Mothers' Day"
        },
        %{
          id: "77777777-7777-4777-8777-777777777777",
          date: ~D[2026-12-23],
          reason_key: "year_end_break",
          label: "Year-end break"
        }
      ]
    }
  end
end
