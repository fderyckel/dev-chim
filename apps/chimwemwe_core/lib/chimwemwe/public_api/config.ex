defmodule Chimwemwe.PublicApi.Config do
  @moduledoc false

  alias Chimwemwe.Identity.Error

  @spec fetch() ::
          {:ok,
           %{
             runtime: Supervisor.supervisor(),
             verifier: module(),
             origin: String.t(),
             preparation: map() | nil,
             sign_in: map() | nil
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
         [] <- Keyword.keys(options) -- [:origin, :preparation, :runtime, :sign_in, :verifier],
         runtime when is_pid(runtime) or is_atom(runtime) <- Keyword.get(options, :runtime),
         verifier when is_atom(verifier) <- Keyword.get(options, :verifier),
         origin when is_binary(origin) <- Keyword.get(options, :origin),
         {:ok, preparation} <- preparation(Keyword.get(options, :preparation)),
         {:ok, sign_in} <- sign_in(Keyword.get(options, :sign_in)),
         {:ok, uri} <- URI.new(origin),
         true <-
           uri.scheme == "https" and is_binary(uri.host) and uri.path in [nil, ""] and
             is_nil(uri.query) and is_nil(uri.fragment) and is_nil(uri.userinfo) do
      {:ok,
       %{
         runtime: runtime,
         verifier: verifier,
         origin: origin,
         preparation: preparation,
         sign_in: sign_in
       }}
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

  defp sign_in(nil), do: {:ok, nil}

  defp sign_in(options) when is_list(options) do
    keys = [
      :actor_id,
      :connection_id,
      :external_identity_link_id,
      :locale,
      :membership_id,
      :redirect_to,
      :tenant_id
    ]

    with true <- Keyword.keyword?(options),
         true <- Enum.sort(Keyword.keys(options)) == Enum.sort(keys),
         {:ok, actor_id} <- Ecto.UUID.cast(Keyword.fetch!(options, :actor_id)),
         {:ok, tenant_id} <- Ecto.UUID.cast(Keyword.fetch!(options, :tenant_id)),
         {:ok, membership_id} <- Ecto.UUID.cast(Keyword.fetch!(options, :membership_id)),
         {:ok, link_id} <- Ecto.UUID.cast(Keyword.fetch!(options, :external_identity_link_id)),
         {:ok, connection_id} <- Ecto.UUID.cast(Keyword.fetch!(options, :connection_id)),
         locale when locale in ["en", "en-MW", "fr"] <- Keyword.fetch!(options, :locale),
         redirect_to when is_binary(redirect_to) <- Keyword.fetch!(options, :redirect_to),
         true <- safe_redirect?(redirect_to) do
      {:ok,
       %{
         actor_id: actor_id,
         tenant_id: tenant_id,
         membership_id: membership_id,
         external_identity_link_id: link_id,
         connection_id: connection_id,
         locale: locale,
         redirect_to: redirect_to
       }}
    else
      _invalid -> error()
    end
  end

  defp sign_in(_invalid), do: error()

  defp safe_redirect?(value) do
    String.starts_with?(value, "/") and not String.starts_with?(value, "//") and
      not String.contains?(value, ["\\", "\r", "\n"]) and byte_size(value) <= 500
  end

  defp error, do: {:error, %Error{code: :retryable_dependency}}
end
