defmodule Chimwemwe.AcademicCalendar.Preview do
  @moduledoc "Deterministic, non-persistent result of validating a publication candidate."

  alias Chimwemwe.AcademicCalendar.Definition

  @enforce_keys [
    :candidate_revision,
    :definition,
    :instructional_date_count,
    :instructional_dates
  ]
  defstruct [:candidate_revision, :definition, :instructional_date_count, :instructional_dates]

  @type t :: %__MODULE__{
          candidate_revision: String.t(),
          definition: Definition.t(),
          instructional_date_count: non_neg_integer(),
          instructional_dates: [Date.t()]
        }
end
