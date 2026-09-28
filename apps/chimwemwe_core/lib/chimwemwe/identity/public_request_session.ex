defmodule Chimwemwe.Identity.PublicRequestSession do
  @moduledoc "Validated server-side request session for the public adapter."

  alias Chimwemwe.Identity.{SessionView, SupportSessionView}
  alias Chimwemwe.Platform.ExecutionContext

  @enforce_keys [:context, :csrf_token, :session, :session_token, :support]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          context: ExecutionContext.t(),
          csrf_token: String.t(),
          session: SessionView.t(),
          session_token: String.t(),
          support: SupportSessionView.t() | nil
        }

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(request, options) do
      concat([
        "#Chimwemwe.Identity.PublicRequestSession<",
        to_doc(
          %{
            context: request.context,
            csrf_token: "[REDACTED]",
            session: request.session,
            session_token: "[REDACTED]",
            support: request.support
          },
          options
        ),
        ">"
      ])
    end
  end
end
