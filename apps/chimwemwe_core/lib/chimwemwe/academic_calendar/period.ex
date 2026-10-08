defmodule Chimwemwe.AcademicCalendar.Period do
  @moduledoc "One ordered primary instructional period within an academic year candidate."

  @enforce_keys [:end_on, :id, :label, :period_type_key, :sequence, :start_on]
  defstruct [:end_on, :id, :label, :period_type_key, :sequence, :start_on]

  @type t :: %__MODULE__{
          end_on: Date.t(),
          id: String.t(),
          label: String.t(),
          period_type_key: String.t(),
          sequence: pos_integer(),
          start_on: Date.t()
        }
end
