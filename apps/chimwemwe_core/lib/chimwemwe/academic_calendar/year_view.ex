defmodule Chimwemwe.AcademicCalendar.YearView do
  @moduledoc "Exact authoritative view of one academic-year definition."

  alias Chimwemwe.AcademicCalendar.Preview

  @enforce_keys [:preview, :status, :lock_version]
  defstruct [:preview, :status, :lock_version]

  @type t :: %__MODULE__{
          preview: Preview.t(),
          status: :draft | :published,
          lock_version: pos_integer()
        }
end
