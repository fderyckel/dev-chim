defmodule Chimwemwe.People.StaffAudience.AuthorityFence do
  @moduledoc false
  alias Chimwemwe.Repo
  alias Ecto.UUID

  # Lock parents before reading their children. FOR UPDATE conflicts with the
  # foreign-key KEY SHARE taken by inserts, protecting absent assignments/edges.
  def capture(tenant, membership_ids) do
    params = [UUID.dump!(tenant), Enum.map(membership_ids, &UUID.dump!/1)]

    memberships =
      Repo.query!(
        """
        SELECT id::text, actor_id::text FROM platform_tenant_memberships
        WHERE tenant_id = $1 AND id = ANY($2::uuid[]) ORDER BY id FOR UPDATE
        """,
        params
      ).rows

    assignments =
      Repo.query!(
        """
        SELECT id::text, membership_id::text, role_id::text, lock_version
        FROM platform_actor_role_assignments WHERE tenant_id = $1 AND membership_id = ANY($2::uuid[])
        ORDER BY id LIMIT 257 FOR UPDATE
        """,
        params
      ).rows

    bounded(assignments, 256)
    roots = assignments |> Enum.map(&Enum.at(&1, 2)) |> Enum.uniq() |> Enum.sort()
    {roles, edges, grants, caps} = walk(tenant, roots, [], [], [], [])
    bounded(assignments ++ edges ++ grants, 256)

    %{
      memberships: memberships,
      assignments: assignments,
      roles: roles,
      edges: edges,
      grants: grants,
      capabilities: caps
    }
  end

  defp walk(_tenant, [], roles, edges, grants, caps),
    do: {Enum.sort(roles), Enum.sort(edges), Enum.sort(grants), Enum.sort(Enum.uniq(caps))}

  defp walk(tenant, pending, roles, edges, grants, caps) do
    seen = Enum.map(roles, &hd/1)
    pending = pending -- seen
    bounded(pending ++ seen, 64)
    rows = role_rows(tenant, pending)
    next_edges = child_rows(tenant, pending, :edges)
    next_grants = child_rows(tenant, pending, :grants)
    bounded(edges ++ next_edges ++ grants ++ next_grants, 256)
    next_caps = capability_rows(tenant, next_grants)
    next = next_edges |> Enum.map(&Enum.at(&1, 2)) |> Enum.uniq() |> Enum.sort()
    next = next -- (seen ++ Enum.map(rows, &hd/1))

    walk(
      tenant,
      next,
      roles ++ rows,
      edges ++ next_edges,
      grants ++ next_grants,
      caps ++ next_caps
    )
  end

  defp role_rows(tenant, ids) do
    Repo.query!(
      """
      SELECT id::text, lock_version FROM platform_roles
      WHERE tenant_id = $1 AND id = ANY($2::uuid[]) ORDER BY id FOR UPDATE
      """,
      params(tenant, ids)
    ).rows
  end

  defp child_rows(tenant, ids, :edges) do
    Repo.query!(
      """
      SELECT id::text, role_id::text, included_role_id::text
      FROM platform_role_inclusions WHERE tenant_id = $1 AND role_id = ANY($2::uuid[])
      ORDER BY id LIMIT 257 FOR UPDATE
      """,
      params(tenant, ids)
    ).rows
  end

  defp child_rows(tenant, ids, :grants) do
    Repo.query!(
      """
      SELECT id::text, role_id::text, capability_id::text
      FROM platform_role_capability_grants WHERE tenant_id = $1 AND role_id = ANY($2::uuid[])
      ORDER BY id LIMIT 257 FOR UPDATE
      """,
      params(tenant, ids)
    ).rows
  end

  defp capability_rows(tenant, grants) do
    ids = grants |> Enum.map(&Enum.at(&1, 2)) |> Enum.uniq()

    Repo.query!(
      """
      SELECT id::text, key FROM platform_capabilities
      WHERE tenant_id = $1 AND id = ANY($2::uuid[]) ORDER BY id FOR SHARE
      """,
      params(tenant, ids)
    ).rows
  end

  defp params(tenant, ids), do: [UUID.dump!(tenant), Enum.map(ids, &UUID.dump!/1)]

  defp bounded(rows, maximum) do
    if length(rows) > maximum, do: Repo.rollback(%Chimwemwe.People.Error{code: :scope_limit})
  end
end
