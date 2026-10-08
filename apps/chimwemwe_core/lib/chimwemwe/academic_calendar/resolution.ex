defmodule Chimwemwe.AcademicCalendar.Resolution do
  @moduledoc "Explicit local-date result from one exact calendar candidate revision."

  @enforce_keys [
    :academic_year_id,
    :calendar_id,
    :candidate_revision,
    :institutional_unit_id,
    :local_date,
    :reason,
    :status
  ]
  defstruct [
    :academic_period_id,
    :academic_year_id,
    :calendar_id,
    :candidate_revision,
    :closure_id,
    :closure_reason_key,
    :institutional_unit_id,
    :local_date,
    :reason,
    :status
  ]

  @type status :: :instructional | :non_instructional
  @type reason :: :closure | :instructional_weekday | :outside_period | :ordinary_weekday_off

  @type t :: %__MODULE__{
          academic_period_id: String.t() | nil,
          academic_year_id: String.t(),
          calendar_id: String.t(),
          candidate_revision: String.t(),
          closure_id: String.t() | nil,
          closure_reason_key: String.t() | nil,
          institutional_unit_id: String.t(),
          local_date: Date.t(),
          reason: reason(),
          status: status()
        }
end
