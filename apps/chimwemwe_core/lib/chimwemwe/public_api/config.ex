defmodule Chimwemwe.PublicApi.Config do
  @moduledoc false

  alias Chimwemwe.Identity.Error

  @spec fetch() ::
          {:ok, %{runtime: Supervisor.supervisor(), verifier: module(), origin: String.t()}}
          | {:error, Error.t()}
  def fetch do
    case Application.get_env(:chimwemwe_core, :public_api) do
      options when is_list(options) -> validate(options)
      _missing_or_invalid -> error()
    end
  end

  defp validate(options) do
    with true <- Keyword.keyword?(options),
         [] <- Keyword.keys(options) -- [:origin, :runtime, :verifier],
         runtime when is_pid(runtime) or is_atom(runtime) <- Keyword.get(options, :runtime),
         verifier when is_atom(verifier) <- Keyword.get(options, :verifier),
         origin when is_binary(origin) <- Keyword.get(options, :origin),
         {:ok, uri} <- URI.new(origin),
         true <-
           uri.scheme == "https" and is_binary(uri.host) and uri.path in [nil, ""] and
             is_nil(uri.query) and is_nil(uri.fragment) and is_nil(uri.userinfo) do
      {:ok, %{runtime: runtime, verifier: verifier, origin: origin}}
    else
      _invalid -> error()
    end
  end

  defp error, do: {:error, %Error{code: :retryable_dependency}}
end
