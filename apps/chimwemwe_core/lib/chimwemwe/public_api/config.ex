defmodule Chimwemwe.PublicApi.Config do
  @moduledoc false

  alias Chimwemwe.Identity.Error

  @spec fetch() ::
          {:ok,
           %{
             runtime: Supervisor.supervisor(),
             verifier: module(),
             origin: String.t(),
             preparation: map() | nil
           }}
          | {:error, Error.t()}
  def fetch do
    case Application.get_env(:chimwemwe_core, :public_api) do
      options when is_list(options) -> validate(options)
      _missing_or_invalid -> error()
    end
  end

  defp validate(options) do
    with true <- Keyword.keyword?(options),
         [] <- Keyword.keys(options) -- [:origin, :preparation, :runtime, :verifier],
         runtime when is_pid(runtime) or is_atom(runtime) <- Keyword.get(options, :runtime),
         verifier when is_atom(verifier) <- Keyword.get(options, :verifier),
         origin when is_binary(origin) <- Keyword.get(options, :origin),
         {:ok, preparation} <- preparation(Keyword.get(options, :preparation)),
         {:ok, uri} <- URI.new(origin),
         true <-
           uri.scheme == "https" and is_binary(uri.host) and uri.path in [nil, ""] and
             is_nil(uri.query) and is_nil(uri.fragment) and is_nil(uri.userinfo) do
      {:ok, %{runtime: runtime, verifier: verifier, origin: origin, preparation: preparation}}
    else
      _invalid -> error()
    end
  end

  defp preparation(nil), do: {:ok, nil}

  defp preparation(options) when is_list(options) do
    with true <- Keyword.keyword?(options),
         [] <- Keyword.keys(options) -- [:people_runtime, :workspace_id],
         %Chimwemwe.People.Runtime{} = people_runtime <- Keyword.get(options, :people_runtime),
         workspace_id when is_binary(workspace_id) <- Keyword.get(options, :workspace_id),
         {:ok, workspace_id} <- Ecto.UUID.cast(workspace_id) do
      {:ok, %{people_runtime: people_runtime, workspace_id: workspace_id}}
    else
      _invalid -> error()
    end
  end

  defp preparation(_invalid), do: error()

  defp error, do: {:error, %Error{code: :retryable_dependency}}
end
