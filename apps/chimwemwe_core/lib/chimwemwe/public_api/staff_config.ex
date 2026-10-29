defmodule Chimwemwe.PublicApi.StaffConfig do
  @moduledoc false
  alias Chimwemwe.Platform.{ExecutionContext, PersistenceRuntime, PlacementRegistry, TrustedActor}
  alias Chimwemwe.PublicApi.Config
  @environment Mix.env()

  def fetch do
    with true <- @environment in [:dev, :test],
         %{tenant_id: tenant, institution_label: label, bootstrap_actor_id: bootstrap} <-
           Application.get_env(:chimwemwe_core, :local_staff_directory),
         {:ok, tenant} <- Ecto.UUID.cast(tenant),
         {:ok, bootstrap} <- Ecto.UUID.cast(bootstrap),
         true <- is_binary(label) and byte_size(label) in 1..160,
         {:ok, config} <- Config.fetch(),
         %{scheme: "https", host: "localhost"} <- URI.parse(config.origin) do
      {:ok,
       Map.merge(config, %{
         tenant_id: tenant,
         institution_label: label,
         bootstrap_actor_id: bootstrap
       })}
    else
      _ -> {:error, :unavailable}
    end
  end

  def context(config, actor_id, locale, purpose) do
    with {:ok, registry} <- PersistenceRuntime.child_pid(config.runtime, PlacementRegistry),
         {:ok, placement} <- PlacementRegistry.current_placement(registry, config.tenant_id),
         {:ok, actor} <-
           TrustedActor.establish(
             actor_id: actor_id,
             tenant_id: config.tenant_id,
             assurance: "password"
           ) do
      ExecutionContext.establish(actor, placement,
        correlation_id: Ecto.UUID.generate(),
        purpose: purpose,
        locale: locale
      )
    end
  end
end
