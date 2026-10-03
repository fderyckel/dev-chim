defmodule Chimwemwe.AcademicCalendar.Error do
  @moduledoc """
  Stable validation and resolution error for the calendar contract.

  The optional field identifies the rejected part of the synthetic candidate;
  it never carries another tenant's record or any restricted information.
  """

  @enforce_keys [:code]
  defexception [:code, :field]

  @type code ::
          :duplicate
          | :invalid_date_range
          | :invalid_input
          | :not_found
          | :overlap
          | :outside_year
          | :unsupported_time_zone

  @type t :: %__MODULE__{code: code(), field: atom() | nil}

  @impl true
  def message(%__MODULE__{code: code, field: nil}), do: "academic calendar failed: #{code}"

  def message(%__MODULE__{code: code, field: field}),
    do: "academic calendar failed: #{code} (#{field})"
end
