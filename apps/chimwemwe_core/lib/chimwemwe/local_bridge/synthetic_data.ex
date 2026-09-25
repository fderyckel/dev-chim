defmodule Chimwemwe.LocalBridge.SyntheticData do
  @moduledoc """
  Deterministic, non-sensitive identities and authority rows for UI-1A only.

  These identifiers are not production principals, tenant records, or role
  constants. They exist solely in the dedicated local qualification database.
  """

  alias Chimwemwe.Platform.{ExecutionContext, TrustedActor, TrustedPlacement}

  @tenant_a "71111111-1111-4111-8111-111111111111"
  @tenant_b "72222222-2222-4222-8222-222222222222"
  @manager_a "7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @denied_a "7ddddddd-dddd-4ddd-8ddd-dddddddddddd"
  @target_a "7ccccccc-cccc-4ccc-8ccc-cccccccccccc"
  @manager_b "7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @target_b "7eeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
  @routing_version 1
  @placement_ref "ui1-local-pool"

  @doc false
  def tenant_a, do: @tenant_a

  @doc false
  def tenant_b, do: @tenant_b

  @doc false
  def manager_a, do: @manager_a

  @doc false
  def denied_a, do: @denied_a

  @doc false
  def manager_b, do: @manager_b

  @doc false
  def placements do
    [placement_entry(@tenant_a), placement_entry(@tenant_b)]
  end

  @doc false
  def authorized_session, do: session(@manager_a, @tenant_a, @routing_version)

  @doc false
  def denied_session, do: session(@denied_a, @tenant_a, @routing_version)

  @doc false
  def stale_session, do: session(@manager_a, @tenant_a, @routing_version + 1)

  @doc false
  def tenant_a_context, do: context(@manager_a, @tenant_a, @routing_version)

  @doc false
  def tenant_b_context, do: context(@manager_b, @tenant_b, @routing_version)

  @doc false
  def seed_rows do
    %{
      memberships: [
        {"71110000-0000-4000-8000-000000000001", @tenant_a, @manager_a},
        {"71110000-0000-4000-8000-000000000002", @tenant_a, @denied_a},
        {"71110000-0000-4000-8000-000000000003", @tenant_a, @target_a},
        {"72220000-0000-4000-8000-000000000001", @tenant_b, @manager_b},
        {"72220000-0000-4000-8000-000000000002", @tenant_b, @target_b}
      ],
      roles: [
        {"71120000-0000-4000-8000-000000000001", @tenant_a, "Assignment manager"},
        {"71120000-0000-4000-8000-000000000002", @tenant_a, "Library review"},
        {"71120000-0000-4000-8000-000000000003", @tenant_a, "Operations review"},
        {"72220000-0000-4000-8000-000000000003", @tenant_b, "Separate tenant role"}
      ],
      capabilities: [
        {"71130000-0000-4000-8000-000000000001", @tenant_a,
         "platform.authority.assignments.create"},
        {"72230000-0000-4000-8000-000000000001", @tenant_b,
         "platform.authority.assignments.create"}
      ],
      assignments: [
        {"71140000-0000-4000-8000-000000000001", @tenant_a,
         "71110000-0000-4000-8000-000000000001", "71120000-0000-4000-8000-000000000001"},
        {"72240000-0000-4000-8000-000000000001", @tenant_b,
         "72220000-0000-4000-8000-000000000001", "72220000-0000-4000-8000-000000000003"}
      ],
      grants: [
        {"71150000-0000-4000-8000-000000000001", @tenant_a,
         "71120000-0000-4000-8000-000000000001", "71130000-0000-4000-8000-000000000001"},
        {"72250000-0000-4000-8000-000000000001", @tenant_b,
         "72220000-0000-4000-8000-000000000003", "72230000-0000-4000-8000-000000000001"}
      ]
    }
  end

  defp placement_entry(tenant_id) do
    [
      tenant_id: tenant_id,
      routing_version: @routing_version,
      profile: :pooled,
      placement_ref: @placement_ref,
      repository: :ui1_local
    ]
  end

  defp session(actor_id, tenant_id, routing_version) do
    {:ok, actor} =
      TrustedActor.establish(
        actor_id: actor_id,
        tenant_id: tenant_id,
        assurance: "local_synthetic"
      )

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: routing_version,
        profile: :pooled,
        placement_ref: @placement_ref
      )

    {actor, placement}
  end

  defp context(actor_id, tenant_id, routing_version) do
    {actor, placement} = session(actor_id, tenant_id, routing_version)

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: Ecto.UUID.generate(),
        purpose: "ui1.local.bootstrap",
        locale: "en"
      )

    context
  end
end
