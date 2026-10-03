defmodule Chimwemwe.AcademicCalendar.Definition do
  @moduledoc """
  Canonical immutable value used by the first calendar publication preview.

  `calendar_id` and `institutional_unit_id` are both explicit. No active unit,
  ancestor, tenant default, or latest-year lookup can supply either identity.
  """

  alias Chimwemwe.AcademicCalendar.{Closure, Period}

  @enforce_keys [
    :academic_year_id,
    :calendar_id,
    :closures,
    :code,
    :end_on,
    :institutional_unit_id,
    :instructional_weekdays,
    :label,
    :periods,
    :start_on,
    :time_zone
  ]
  defstruct [
    :academic_year_id,
    :calendar_id,
    :closures,
    :code,
    :end_on,
    :institutional_unit_id,
    :instructional_weekdays,
    :label,
    :periods,
    :start_on,
    :time_zone
  ]

  @type t :: %__MODULE__{
          academic_year_id: String.t(),
          calendar_id: String.t(),
          closures: [Closure.t()],
          code: String.t(),
          end_on: Date.t(),
          institutional_unit_id: String.t(),
          instructional_weekdays: [1..7],
          label: String.t(),
          periods: [Period.t()],
          start_on: Date.t(),
          time_zone: String.t()
        }
end
