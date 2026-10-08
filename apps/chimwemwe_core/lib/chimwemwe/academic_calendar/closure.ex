defmodule Chimwemwe.AcademicCalendar.Closure do
  @moduledoc "One named non-instructional local date in an academic year candidate."

  @enforce_keys [:date, :id, :label, :reason_key]
  defstruct [:date, :id, :label, :reason_key]

  @type t :: %__MODULE__{
          date: Date.t(),
          id: String.t(),
          label: String.t(),
          reason_key: String.t()
        }
end
