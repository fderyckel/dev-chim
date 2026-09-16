defmodule Chimwemwe.Platform.InvocationError do
  @moduledoc """
  A non-disclosing failure returned by the trusted Ash invocation boundary.

  Detailed resource and action discovery errors remain internal to code and
  never become a schema-probing surface for callers.
  """

  @enforce_keys [:code]
  defstruct [:code]

  @type code :: :invalid_input | :read_action_not_available | :resource_not_available
  @type t :: %__MODULE__{code: code()}
end
