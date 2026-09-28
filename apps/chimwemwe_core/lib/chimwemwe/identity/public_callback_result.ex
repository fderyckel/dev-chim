defmodule Chimwemwe.Identity.PublicCallbackResult do
  @moduledoc "Result of a provider-neutral callback and application-session creation."

  alias Chimwemwe.Identity.SessionView

  @enforce_keys [:cookie_value, :redirect_to, :session]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          cookie_value: String.t(),
          redirect_to: String.t(),
          session: SessionView.t()
        }

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(result, options) do
      concat([
        "#Chimwemwe.Identity.PublicCallbackResult<",
        to_doc(%{cookie_value: "[REDACTED]", redirect_to: result.redirect_to}, options),
        ">"
      ])
    end
  end
end
