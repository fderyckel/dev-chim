defmodule Chimwemwe.People.StaffAudience.Source do
  @moduledoc false
  alias Chimwemwe.Identity.{AccountSourceFence, SessionFoundation}
  alias Chimwemwe.People.{Error, Foundation}
  alias Chimwemwe.People.StaffAudience.{AuthorityFence, Clock}
  alias Chimwemwe.Platform.{Authority, ModuleLifecycle, TrustedActor}
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @capability "people.core.audiences.prepare_staff"

  def session(runtime, request, actor) do
    observed_deadline = observe_session_deadline(request, actor)
    validate_session!(runtime, request, actor)

    rows =
      Repo.query!(
        """
        SELECT id::text, membership_id::text, external_identity_link_id::text,
          LEAST(idle_expires_at, absolute_expires_at)
        FROM identity_application_sessions
        WHERE tenant_id = $1 AND actor_id = $2 AND token_digest = $3 AND status = 'active'
          AND idle_expires_at > (clock_timestamp() AT TIME ZONE 'UTC')
          AND absolute_expires_at > (clock_timestamp() AT TIME ZONE 'UTC')
        FOR UPDATE
        """,
        [
          dump(actor.tenant_id),
          dump(actor.actor_id),
          :crypto.hash(:sha256, request.session_token)
        ]
      ).rows

    case rows do
      [[id, member, link, deadline]] ->
        if id != request.session.id or member != request.session.membership_id or
             request.session.actor_id != actor.actor_id or
             request.session.tenant_id != actor.tenant_id,
           do: fail(:forbidden)

        if link, do: origin(link, actor.actor_id)
        %{id: id, membership_id: member, deadline: Clock.earlier(observed_deadline, deadline)}

      _ ->
        fail(:forbidden)
    end
  end

  # Idle refresh may extend a later request, never this already-started operation.
  # This observation grants no authority: ordinary validation then locks and
  # rechecks the current session, origin and membership on the same writer.
  def observe_session_deadline(request, actor) do
    case Repo.query!(
           """
           SELECT LEAST(idle_expires_at,absolute_expires_at) FROM identity_application_sessions
           WHERE tenant_id=$1 AND actor_id=$2 AND token_digest=$3 AND status='active'
             AND idle_expires_at > (clock_timestamp() AT TIME ZONE 'UTC')
             AND absolute_expires_at > (clock_timestamp() AT TIME ZONE 'UTC')
           """,
           [
             dump(actor.tenant_id),
             dump(actor.actor_id),
             :crypto.hash(:sha256, request.session_token)
           ]
         ).rows do
      [[deadline]] -> deadline
      _ -> fail(:forbidden)
    end
  end

  defp validate_session!(runtime, request, actor) do
    case SessionFoundation.validate(runtime, request.context, %{token: request.session_token}) do
      {:ok, current}
      when current.id == request.session.id and
             current.membership_id == request.session.membership_id and
             current.actor_id == actor.actor_id and current.tenant_id == actor.tenant_id ->
        :ok

      {:error, %{code: :retryable_dependency}} ->
        fail(:retryable_dependency)

      _ ->
        fail(:forbidden)
    end
  end

  def capture(context, institution, session, additional_memberships \\ []) do
    actor = context.actor
    tenant = TrustedActor.tenant_id(actor)
    module_basis = modules(context)
    # Named writers already hold this tenant fence. Database guards now cover
    # alternate writes too. Calling the primitive fails closed on an old schema.
    Repo.query!("SELECT people_source_lock($1::uuid)", [dump(tenant)])
    unit = institution(tenant, institution)
    time = Clock.basis(unit.zone)
    Clock.bound(Clock.earlier(time.midnight, session.deadline))
    parts = participations(tenant, institution)
    current_parts = Enum.filter(parts, &current?(&1, time.date))
    if length(current_parts) > 25, do: fail(:scope_limit)
    people = people(tenant, parts)
    associations = associations(tenant, parts)
    current_ids = Enum.map(current_parts, &hd/1)

    current_associations =
      Enum.filter(associations, fn [_id, _person, part, _member, _actor, revoked, _v] ->
        part in current_ids and is_nil(revoked)
      end)

    memberships =
      [
        session.membership_id
        | additional_memberships ++ Enum.map(current_associations, &Enum.at(&1, 3))
      ]
      |> Enum.uniq()
      |> Enum.sort()

    authority = AuthorityFence.capture(tenant, memberships)

    unless [session.membership_id, TrustedActor.actor_id(actor)] in authority.memberships,
      do: fail(:forbidden)

    source_members = Enum.map(current_associations, &Enum.at(&1, 3))

    actual_actors =
      authority.memberships
      |> Enum.filter(fn [member, _actor] -> member in source_members end)
      |> Enum.map(&Enum.at(&1, 1))
      |> Enum.uniq()
      |> Enum.sort()

    case AccountSourceFence.lock_current_transaction(context, actual_actors) do
      :ok -> :ok
      {:error, reason} -> fail(reason)
    end

    accounts = accounts(actual_actors)
    authorize(context)
    current = Clock.basis(unit.zone)
    if current.date != time.date, do: fail(:stale)
    Clock.current_before(session.deadline)
    subjects = subjects(parts, associations, authority, accounts, current.date, tenant)
    if map_size(subjects) > 25, do: fail(:scope_limit)
    population_authority = AuthorityFence.audience_basis(authority, source_members)

    basis =
      {unit, parts, people, associations, population_authority, accounts, current.date,
       module_basis}

    %{
      subjects: subjects,
      basis: basis,
      time: current,
      deadline: Clock.earlier(current.midnight, session.deadline)
    }
  end

  def recipient(context, institution, session, original) do
    tenant = TrustedActor.tenant_id(context.actor)
    actor = TrustedActor.actor_id(context.actor)
    modules(context, "communications.core.notices.read")
    unit = institution(tenant, institution)
    time = Clock.basis(unit.zone)
    deadline = Clock.earlier(time.midnight, session.deadline)
    Clock.bound(deadline)
    authority = AuthorityFence.capture(tenant, [session.membership_id])

    unless [session.membership_id, actor] in authority.memberships and
             original.actor_id == actor and original.membership_id == session.membership_id,
           do: fail(:forbidden)

    case AccountSourceFence.lock_current_transaction(context, [actor]) do
      :ok -> :ok
      {:error, reason} -> fail(reason)
    end

    rows =
      Repo.query!(
        """
        SELECT p.id FROM people_participations p
        JOIN people_staff_account_associations a ON a.participation_id = p.id AND a.tenant_id = p.tenant_id
        WHERE p.tenant_id = $1 AND p.id = $2 AND p.person_id = $3 AND p.institutional_unit_id = $4
          AND p.kind = 'staff' AND p.effective_from <= $8 AND (p.effective_until IS NULL OR p.effective_until > $8)
          AND a.id = $5 AND a.person_id = p.person_id AND a.membership_id = $6
          AND a.verification->>'actor_id' = $7 AND a.revoked_at IS NULL
        FOR SHARE OF p, a
        """,
        [
          dump(tenant),
          dump(original.participation_id),
          dump(original.person_id),
          dump(institution),
          dump(original.association_id),
          dump(session.membership_id),
          actor,
          time.date
        ]
      ).rows

    admitted = account_matches?(original, accounts([actor]))

    unless rows != [] and admitted and notice_capability?(tenant, actor), do: fail(:forbidden)
    %{person_id: original.person_id, deadline: deadline}
  end

  defp account_matches?(original, accounts) do
    Enum.any?(accounts, fn [id, actor, binding, status, _version] ->
      id == original.account_id and actor == original.actor_id and
        binding == original.principal_binding_id and status == "active"
    end)
  end

  defp origin(link, actor) do
    rows =
      Repo.query!(
        """
        SELECT l.id FROM identity_external_identity_links l
        JOIN identity_connections c ON c.id = l.connection_id AND c.tenant_id = l.origin_tenant_id
        WHERE l.id = $1 AND l.actor_id = $2 AND l.status = 'active' AND c.status = 'active'
          AND l.connection_configuration_version = c.configuration_version
          AND l.protocol = c.protocol AND l.issuer = c.issuer
        FOR SHARE OF l, c
        """,
        [dump(link), dump(actor)]
      ).rows

    if rows == [], do: fail(:forbidden)
  end

  defp modules(context, capability \\ @capability) do
    manifest = Foundation.release_manifest()
    # People first follows its existing named writers; explicitly fence every
    # dependency, whose ordinary availability check alone takes no dependency lock.
    keys = [
      "people.core"
      | Enum.map(ReleaseManifest.declarations(manifest), & &1.key) -- ["people.core"]
    ]

    Enum.each(keys, fn key ->
      case ModuleLifecycle.available_current_transaction(manifest, context, key) do
        :ok -> :ok
        _ -> fail(:module_unavailable)
      end
    end)

    authorize(context, capability)

    Repo.query!(
      """
      SELECT e.id::text, e.module_key, a.id::text, a.module_version, a.lock_version
      FROM platform_module_entitlements e JOIN platform_module_activations a
        ON a.entitlement_id = e.id AND a.tenant_id = e.tenant_id
      WHERE e.tenant_id = $1 AND e.module_key = ANY($2::text[])
      ORDER BY e.module_key FOR SHARE OF e, a
      """,
      [dump(TrustedActor.tenant_id(context.actor)), keys]
    ).rows
  end

  defp authorize(context, capability \\ @capability) do
    case ModuleLifecycle.authorize_current_transaction(
           Foundation.release_manifest(),
           context,
           "people.core",
           capability
         ) do
      :ok -> :ok
      _ -> fail(:forbidden)
    end
  end

  defp institution(tenant, id) do
    case Repo.query!(
           """
           SELECT id::text, time_zone, lock_version FROM institutional_units
           WHERE tenant_id = $1 AND id = $2 AND status = 'published' FOR SHARE
           """,
           [dump(tenant), dump(id)]
         ).rows do
      [[id, zone, version]] -> %{id: id, zone: zone, version: version}
      _ -> fail(:forbidden)
    end
  end

  defp participations(tenant, institution) do
    rows =
      Repo.query!(
        """
        SELECT id::text, person_id::text, effective_from, effective_until, lock_version
        FROM people_participations WHERE tenant_id = $1 AND institutional_unit_id = $2 AND kind = 'staff'
        ORDER BY id LIMIT 101
        """,
        [dump(tenant), dump(institution)]
      ).rows

    bounded(rows, 100)
    rows
  end

  defp people(tenant, parts) do
    Repo.query!(
      """
      SELECT id::text, lock_version FROM people_persons
      WHERE tenant_id = $1 AND id = ANY($2::uuid[]) ORDER BY id
      """,
      [dump(tenant), Enum.map(parts, &dump(Enum.at(&1, 1)))]
    ).rows
  end

  defp associations(tenant, parts) do
    rows =
      Repo.query!(
        """
        SELECT id::text, person_id::text, participation_id::text, membership_id::text,
          verification->>'actor_id', revoked_at, lock_version
        FROM people_staff_account_associations WHERE tenant_id = $1 AND participation_id = ANY($2::uuid[])
        ORDER BY id LIMIT 257
        """,
        [dump(tenant), Enum.map(parts, &dump(hd(&1)))]
      ).rows

    bounded(rows, 256)
    rows
  end

  defp accounts(actors) do
    Repo.query!(
      """
      SELECT id::text, actor_id::text, principal_binding_id, status, lock_version
      FROM identity_accounts WHERE actor_id = ANY($1::uuid[]) ORDER BY id
      """,
      [Enum.map(actors, &dump/1)]
    ).rows
  end

  defp subjects(parts, associations, authority, accounts, date, tenant) do
    parts
    |> Enum.filter(&current?(&1, date))
    |> Enum.map(fn [part, person, _first, _last, _version] ->
      association =
        Enum.find(associations, fn [_id, p, participation, _member, _actor, revoked, _v] ->
          p == person and participation == part and is_nil(revoked)
        end)

      admission = admission(association, authority.memberships, accounts, part, person)
      eligible = not is_nil(admission) and notice_capability?(tenant, admission.actor_id)
      {person, %{participation_id: part, admission: admission, eligible: eligible}}
    end)
    |> Map.new()
  end

  defp admission(nil, _members, _accounts, _part, _person), do: nil

  defp admission(
         [association, person, part, member, actor, nil, _version],
         members,
         accounts,
         part,
         person
       ) do
    account =
      Enum.find(accounts, fn [_id, a, marker, status, _v] ->
        a == actor and status == "active" and is_integer(marker) and marker > 0
      end)

    if [member, actor] in members and not is_nil(account) do
      [id, ^actor, binding, _status, _v] = account

      %{
        person_id: person,
        participation_id: part,
        association_id: association,
        membership_id: member,
        actor_id: actor,
        account_id: id,
        principal_binding_id: binding
      }
    end
  end

  defp notice_capability?(tenant, actor) do
    {:ok, trusted} =
      TrustedActor.establish(actor_id: actor, tenant_id: tenant, assurance: "authenticated")

    Authority.actor_has_capability?(
      trusted,
      "communications.core.notices.read"
    )
  end

  defp bounded(rows, cap), do: if(length(rows) > cap, do: fail(:scope_limit))

  defp current?([_id, _person, first, last, _version], date),
    do: Date.compare(first, date) != :gt and (is_nil(last) or Date.compare(date, last) == :lt)

  defp dump(id), do: UUID.dump!(id)
  defp fail(code), do: Repo.rollback(%Error{code: code})
end
