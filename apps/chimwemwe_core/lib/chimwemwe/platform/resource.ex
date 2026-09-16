defmodule Chimwemwe.Platform.Resource do
  @moduledoc """
  The code-owned base for Ash resources in the production platform boundary.

  A resource must declare whether it is tenant-owned or global reference data.
  The base installs the policy authorizer; `ResourceContract` verifies the
  remaining ownership, tenancy, policy, domain, and action-name rules.
  """

  @type ownership :: :tenant_owned | :global_reference

  @callback __chimwemwe_resource_ownership__() :: ownership()

  @allowed_ownerships [:tenant_owned, :global_reference]

  defmacro __using__(opts) do
    ownership = Keyword.get(opts, :ownership)

    unless ownership in @allowed_ownerships do
      raise ArgumentError,
            "Chimwemwe resources require ownership: :tenant_owned or :global_reference"
    end

    unless Keyword.has_key?(opts, :domain) do
      raise ArgumentError, "Chimwemwe resources require an explicit Ash domain"
    end

    if Keyword.has_key?(opts, :authorizers) do
      raise ArgumentError,
            "Chimwemwe.Platform.Resource owns the Ash authorizer configuration"
    end

    ash_opts =
      opts
      |> Keyword.delete(:ownership)
      |> Keyword.put_new(:otp_app, :chimwemwe_core)
      |> Keyword.put(:authorizers, [Ash.Policy.Authorizer])

    quote do
      @behaviour Chimwemwe.Platform.Resource

      use Ash.Resource, unquote(ash_opts)

      @impl Chimwemwe.Platform.Resource
      def __chimwemwe_resource_ownership__, do: unquote(ownership)
    end
  end
end
