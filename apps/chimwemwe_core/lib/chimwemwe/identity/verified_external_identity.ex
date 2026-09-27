defmodule Chimwemwe.Identity.VerifiedExternalIdentity do
  @moduledoc """
  Provider-neutral identity evidence established by a trusted adapter.

  This value contains only normalized protocol evidence needed by the account-
  link boundary. Email addresses, domains, display names, provider groups, and
  provider roles are intentionally absent and cannot create authority.
  """

  alias Ash.Type.UUID
  alias Chimwemwe.Identity.Error

  @protocols [:oidc, :saml]
  @enforce_keys [:connection_id, :protocol, :issuer, :subject, :assurance, :authenticated_at]
  defstruct [:connection_id, :protocol, :issuer, :subject, :assurance, :authenticated_at]

  @opaque t :: %__MODULE__{
            connection_id: String.t(),
            protocol: :oidc | :saml,
            issuer: String.t(),
            subject: String.t(),
            assurance: String.t(),
            authenticated_at: DateTime.t()
          }

  @doc "Builds evidence only for a trusted identity-adapter boundary."
  @spec establish(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def establish(attributes) when is_list(attributes) do
    with {:ok, connection_id} <- uuid(Keyword.get(attributes, :connection_id)),
         {:ok, protocol} <- protocol(Keyword.get(attributes, :protocol)),
         {:ok, issuer} <- normalized_identifier(Keyword.get(attributes, :issuer), 500),
         {:ok, subject} <- normalized_identifier(Keyword.get(attributes, :subject), 500),
         {:ok, assurance} <- normalized_identifier(Keyword.get(attributes, :assurance), 120),
         {:ok, authenticated_at} <- timestamp(Keyword.get(attributes, :authenticated_at)) do
      {:ok,
       %__MODULE__{
         connection_id: connection_id,
         protocol: protocol,
         issuer: issuer,
         subject: subject,
         assurance: assurance,
         authenticated_at: authenticated_at
       }}
    end
  end

  def establish(_attributes), do: error(:invalid_input)

  @doc false
  @spec validate(term()) :: :ok | {:error, Error.t()}
  def validate(%__MODULE__{} = proof) do
    with {:ok, _connection_id} <- uuid(proof.connection_id),
         {:ok, _protocol} <- protocol(proof.protocol),
         {:ok, normalized_issuer} <- normalized_identifier(proof.issuer, 500),
         true <- normalized_issuer == proof.issuer,
         {:ok, normalized_subject} <- normalized_identifier(proof.subject, 500),
         true <- normalized_subject == proof.subject,
         {:ok, _assurance} <- normalized_identifier(proof.assurance, 120),
         {:ok, _authenticated_at} <- timestamp(proof.authenticated_at) do
      :ok
    else
      _invalid -> error(:invalid_input)
    end
  end

  def validate(_proof), do: error(:invalid_input)

  defp uuid(value) do
    case UUID.cast_input(value, []) do
      {:ok, uuid} -> {:ok, uuid}
      _invalid -> error(:invalid_input)
    end
  end

  defp protocol(value) when value in @protocols, do: {:ok, value}
  defp protocol(_value), do: error(:invalid_input)

  defp normalized_identifier(value, maximum) when is_binary(value) do
    normalized = String.trim(value)

    if normalized != "" and String.length(normalized) <= maximum do
      {:ok, normalized}
    else
      error(:invalid_input)
    end
  end

  defp normalized_identifier(_value, _maximum), do: error(:invalid_input)

  defp timestamp(%DateTime{} = value), do: {:ok, DateTime.truncate(value, :microsecond)}
  defp timestamp(_value), do: error(:invalid_input)

  defp error(code), do: {:error, %Error{code: code}}
end
