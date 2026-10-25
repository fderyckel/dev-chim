defmodule Chimwemwe.Identity.StaffDirectory do
  @moduledoc "Privileged, tenant-qualified synthetic staff account administration under ADR 0049."
  alias Chimwemwe.Identity.{Error, InternalWriter, LocalCredentials, StaffDirectoryEvidence}
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.Platform.{Authority, ModuleLifecycle}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @aggregate "identity.staff_accounts.entry"
  @ceiling [
    "classroom.attendance.read",
    "classroom.attendance.submit",
    "classroom.attendance.correct",
    "classroom.core.classes.read"
  ]
  @common [:idempotency_key, :causation_id]
  @details [:given_name, :family_name, :display_name, :locale]
  @actions %{
    provision: {"identity.staff_accounts.provision", [:association_id, :email] ++ @details},
    revise_details: {"identity.staff_accounts.manage", [:id, :expected_version] ++ @details},
    set_access: {"identity.staff_accounts.access", [:id, :expected_version, :profile_id]},
    revoke_access_profile:
      {"identity.staff_accounts.access", [:id, :expected_version, :profile_id]},
    suspend_access: {"identity.staff_accounts.access", [:id, :expected_version]},
    reissue: {"identity.staff_accounts.manage", [:id, :expected_version]},
    set_preferences: {nil, [:locale, :expected_version]}
  }

  @source """
  FROM people_staff_account_associations s
  JOIN people_participations p ON p.id=s.participation_id AND p.tenant_id=s.tenant_id AND p.person_id=s.person_id
  JOIN people_persons person ON person.id=s.person_id AND person.tenant_id=s.tenant_id
  JOIN institutional_units u ON u.id=p.institutional_unit_id AND u.tenant_id=p.tenant_id
  JOIN platform_tenant_memberships m ON m.id=s.membership_id AND m.tenant_id=s.tenant_id
  """
  @current """
  s.revoked_at IS NULL AND p.kind='staff' AND u.status='published'
  AND s.verification->>'actor_id'=m.actor_id::text
  AND p.effective_from <= (statement_timestamp() AT TIME ZONE u.time_zone)::date
  AND (p.effective_until IS NULL OR p.effective_until > (statement_timestamp() AT TIME ZONE u.time_zone)::date)
  """

  def inventory(runtime, context) do
    run(runtime, context, "identity.staff_accounts.read", fn actor ->
      with {:ok, accounts} <- accounts(actor),
           {:ok, candidates} <- candidates(actor),
           {:ok, profiles} <- profiles(actor),
           :ok <-
             ensure(
               length(accounts) <= 25 and length(candidates) <= 25 and length(profiles) <= 25,
               :scope_limit
             ),
           :ok <- audit_inventory(actor, accounts, candidates) do
        {:ok,
         %{accounts: accounts, eligible_staff: candidates, profiles: profiles, truncated: false}}
      end
    end)
  end

  defp audit_inventory(actor, accounts, candidates) do
    observation_id = UUID.generate()

    write(
      """
      INSERT INTO platform_authority_audit_events
        (id,tenant_id,actor_id,action_name,aggregate_type,aggregate_id,idempotency_key,
         correlation_id,causation_id,before_version,after_version,change_summary,occurred_at,inserted_at)
      VALUES ($1,$2,$3,'identity.staff_accounts.inventory','identity.staff_accounts.inventory',$1,$1,
        $4,$4,0,1,$5::jsonb,NOW(),NOW())
      """,
      [
        dump(observation_id),
        dump(actor.tenant_id),
        dump(actor.actor_id),
        dump(actor.correlation_id),
        %{
          "action" => "inventory_observed",
          "account_count" => length(accounts),
          "candidate_count" => length(candidates)
        }
      ]
    )
  end

  def preferences(runtime, context) do
    run(runtime, context, nil, fn actor ->
      with {:ok, entry} <- own_entry(actor),
           do:
             {:ok,
              Map.take(entry, [
                :id,
                :given_name,
                :family_name,
                :display_name,
                :locale,
                :lock_version
              ])}
    end)
  end

  for operation <- Map.keys(@actions) do
    def unquote(operation)(runtime, context, input),
      do: mutate(runtime, context, unquote(operation), input)
  end

  defp run(runtime, context, capability, operation) do
    InternalWriter.run(runtime, context, fn actor ->
      with :ok <- authorize(context, actor, capability),
           :ok <- caller_current(actor),
           do: operation.(actor)
    end)
  end

  defp authorize(context, _actor, nil) do
    case ModuleLifecycle.available_current_transaction(
           People.release_manifest(),
           context,
           "people.core"
         ) do
      :ok -> :ok
      {:error, %{code: :retryable_dependency}} -> error(:retryable_dependency)
      _unavailable -> error(:module_unavailable)
    end
  end

  defp authorize(context, _actor, capability) do
    case ModuleLifecycle.authorize_current_transaction(
           People.release_manifest(),
           context,
           "people.core",
           capability
         ) do
      :ok -> :ok
      {:error, %{code: :forbidden}} -> error(:forbidden)
      {:error, %{code: :retryable_dependency}} -> error(:retryable_dependency)
      _denied -> error(:module_unavailable)
    end
  end

  defp caller_current(actor) do
    case Repo.query(
           "SELECT s.id " <>
             @source <>
             " WHERE s.tenant_id=$1 AND m.actor_id=$2 AND " <>
             @current <> " FOR SHARE OF s,p,person,u,m",
           [dump(actor.tenant_id), dump(actor.actor_id)]
         ) do
      {:ok, %{rows: [_row]}} -> :ok
      {:ok, _missing} -> error(:forbidden)
      _failed -> error(:retryable_dependency)
    end
  end

  defp mutate(runtime, context, operation, raw) do
    capability = elem(Map.fetch!(@actions, operation), 0)

    run(runtime, context, capability, fn actor ->
      with {:ok, input} <- normalize(operation, raw),
           :ok <- extra_authority(context, actor, operation),
           {:ok, target} <- target(actor, operation, input),
           action = "identity.staff_accounts." <> Atom.to_string(operation),
           hash = :crypto.hash(:sha256, :erlang.term_to_binary({action, input}, [:deterministic])),
           {:ok, claim} <-
             StaffDirectoryEvidence.claim(
               actor,
               action,
               @aggregate,
               input.idempotency_key,
               hash,
               target
             ) do
        execute(claim, actor, operation, input, target, action, hash)
      end
    end)
  end

  defp extra_authority(context, actor, :reissue),
    do: authorize(context, actor, "identity.account_security.manage")

  defp extra_authority(_context, _actor, _operation), do: :ok
  defp target(_actor, :provision, _input), do: {:ok, UUID.generate()}

  defp target(actor, :set_preferences, _input) do
    with {:ok, entry} <- own_entry(actor), do: {:ok, entry.id}
  end

  defp target(_actor, _operation, input), do: {:ok, input.id}

  defp execute({:existing, stored}, actor, _operation, _input, _target, _action, hash) do
    with {:ok, replay} <- StaffDirectoryEvidence.replay(stored, actor.actor_id, hash),
         do: receipt(replay.result_payload, replay.audit_reference, replay.event_id, nil)
  end

  defp execute({:new, claim_id}, actor, operation, input, target, action, _hash) do
    with {:ok, entry, temporary} <- perform(actor, operation, input, target),
         payload = %{
           "id" => entry.id,
           "account_id" => entry.account_id,
           "lock_version" => entry.lock_version
         },
         {:ok, evidence} <-
           StaffDirectoryEvidence.record(actor, %{
             action_name: action,
             aggregate_type: @aggregate,
             aggregate_id: entry.id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: entry.lock_version - 1,
             after_version: entry.lock_version,
             change_summary: %{"action" => Atom.to_string(operation)},
             event_type: action <> ".completed",
             event_payload: payload,
             result_payload: payload,
             claim_id: claim_id
           }) do
      receipt(payload, evidence.audit_reference, evidence.event_id, temporary)
    end
  end

  defp receipt(payload, audit, event, temporary) do
    {:ok,
     %{
       id: payload["id"],
       account_id: payload["account_id"],
       lock_version: payload["lock_version"],
       audit_reference: audit,
       event_id: event,
       temporary_password: temporary && temporary.password,
       temporary_password_expires_at: temporary && temporary.expires_at
     }}
  end

  defp perform(actor, :provision, input, id) do
    with :ok <- inventory_capacity(actor),
         {:ok, source} <- source(actor, input.association_id),
         {:ok, %{account: account, temporary_password: password}} <-
           LocalCredentials.provision(input.email, source.actor_id),
         :ok <-
           write(
             """
             INSERT INTO identity_staff_directory_entries
               (id,tenant_id,association_id,membership_id,actor_id,account_id,given_name,family_name,display_name,locale,enabled,lock_version,inserted_at,updated_at)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,true,1,NOW(),NOW())
             """,
             [
               dump(id),
               dump(actor.tenant_id),
               dump(input.association_id),
               dump(source.membership_id),
               dump(source.actor_id),
               dump(account.id),
               input.given_name,
               input.family_name,
               input.display_name,
               input.locale
             ]
           ) do
      {:ok, %{id: id, account_id: account.id, lock_version: 1},
       %{
         password: password,
         expires_at: DateTime.to_iso8601(account.temporary_password_expires_at)
       }}
    else
      {:error, %Ash.Error.Invalid{}} -> error(:conflict)
      other -> other
    end
  end

  defp perform(actor, :reissue, input, id) do
    with {:ok, entry} <- locked_entry(actor, id),
         :ok <- ensure(entry.actor_id != actor.actor_id, :forbidden),
         :ok <- ensure(entry.lock_version == input.expected_version, :stale),
         {:ok, _source} <- source(actor, entry.association_id),
         :ok <- ensure(entry.enabled, :forbidden),
         {:ok, %{rows: [[false]]}} <-
           Repo.query(
             "SELECT EXISTS(SELECT 1 FROM platform_tenant_memberships WHERE actor_id=$1 AND tenant_id<>$2)",
             [dump(entry.actor_id), dump(actor.tenant_id)]
           ),
         {:ok, result} <- LocalCredentials.reissue(entry.account_id),
         :ok <- bump(actor, entry, "", []) do
      {:ok, %{entry | lock_version: entry.lock_version + 1},
       %{
         password: result.temporary_password,
         expires_at: DateTime.to_iso8601(result.account.temporary_password_expires_at)
       }}
    else
      {:ok, %{rows: [[true]]}} -> error(:forbidden)
      other -> other
    end
  end

  defp perform(actor, operation, input, id) do
    with {:ok, entry} <- locked_entry(actor, id),
         :ok <- ensure(entry.lock_version == input.expected_version, :stale),
         :ok <- modify(actor, entry, operation, input),
         {:ok, updated} <- entry(actor, id) do
      {:ok, updated, nil}
    end
  end

  defp modify(actor, entry, :revise_details, input) do
    with {:ok, _source} <- source(actor, entry.association_id) do
      write(
        """
        UPDATE identity_staff_directory_entries SET given_name=$3,family_name=$4,display_name=$5,locale=$6,lock_version=lock_version+1,updated_at=NOW() WHERE tenant_id=$1 AND id=$2
        """,
        [
          dump(actor.tenant_id),
          dump(entry.id),
          input.given_name,
          input.family_name,
          input.display_name,
          input.locale
        ]
      )
    end
  end

  defp modify(actor, entry, :set_preferences, input) do
    with :ok <- ensure(entry.actor_id == actor.actor_id and entry.enabled, :forbidden) do
      bump(actor, entry, "locale=$3,", [input.locale])
    end
  end

  defp modify(actor, entry, :suspend_access, _input) do
    with :ok <- ensure(entry.actor_id != actor.actor_id, :forbidden),
         do: bump(actor, entry, "enabled=false,access_version=access_version+1,", [])
  end

  defp modify(actor, entry, operation, input)
       when operation in [:set_access, :revoke_access_profile] do
    with :ok <- ensure(entry.actor_id != actor.actor_id, :forbidden),
         {:ok, _source} <- source(actor, entry.association_id),
         :ok <- profile_allowed(actor, input.profile_id),
         :ok <- assignment(actor, entry, operation, input.profile_id) do
      bump(actor, entry, "access_version=access_version+1,", [])
    end
  end

  defp bump(actor, entry, changes, extra),
    do:
      write(
        "UPDATE identity_staff_directory_entries SET " <>
          changes <> "lock_version=lock_version+1,updated_at=NOW() WHERE tenant_id=$1 AND id=$2",
        [dump(actor.tenant_id), dump(entry.id)] ++ extra
      )

  defp assignment(actor, entry, :set_access, profile_id) do
    case Repo.query(
           """
           INSERT INTO platform_actor_role_assignments(id,tenant_id,membership_id,role_id,lock_version,inserted_at)
           VALUES($1,$2,$3,$4,1,NOW()) ON CONFLICT (tenant_id,membership_id,role_id) DO NOTHING
           """,
           [
             dump(UUID.generate()),
             dump(actor.tenant_id),
             dump(entry.membership_id),
             dump(profile_id)
           ]
         ) do
      {:ok, _} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp assignment(actor, entry, :revoke_access_profile, profile_id) do
    case Repo.query(
           "DELETE FROM platform_actor_role_assignments WHERE tenant_id=$1 AND membership_id=$2 AND role_id=$3",
           [dump(actor.tenant_id), dump(entry.membership_id), dump(profile_id)]
         ) do
      {:ok, _} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp profile_allowed(actor, id) do
    with {:ok, %{rows: rows}} <-
           Repo.query(
             """
             WITH RECURSIVE selected(id) AS (
               SELECT id FROM platform_roles WHERE tenant_id=$1 AND id=$2
               UNION SELECT i.included_role_id FROM platform_role_inclusions i JOIN selected s ON s.id=i.role_id WHERE i.tenant_id=$1
             )
             SELECT DISTINCT c.key FROM selected s JOIN platform_role_capability_grants g ON g.role_id=s.id AND g.tenant_id=$1
             JOIN platform_capabilities c ON c.id=g.capability_id AND c.tenant_id=g.tenant_id
             """,
             [dump(actor.tenant_id), dump(id)]
           ),
         keys = List.flatten(rows),
         :ok <-
           ensure(
             keys != [] and
               Enum.all?(
                 keys,
                 &(&1 in @ceiling and Authority.actor_has_capability?(actor.actor, &1))
               ),
             :forbidden
           ) do
      :ok
    else
      {:error, _} = failure -> failure
    end
  end

  defp profiles(actor) do
    with {:ok, %{rows: rows}} <-
           Repo.query(
             "SELECT id::text,name FROM platform_roles WHERE tenant_id=$1 ORDER BY name,id LIMIT 26",
             [dump(actor.tenant_id)]
           ),
         :ok <- ensure(length(rows) <= 25, :scope_limit) do
      {:ok,
       for([id, label] <- rows, profile_allowed(actor, id) == :ok, do: %{id: id, label: label})}
    else
      {:error, %Error{}} = failed -> failed
      _failed -> error(:retryable_dependency)
    end
  end

  defp source(actor, association_id) do
    one(
      "SELECT s.membership_id::text,m.actor_id::text " <>
        @source <>
        " WHERE s.tenant_id=$1 AND s.id=$2 AND " <> @current <> " FOR SHARE OF s,p,person,u,m",
      [dump(actor.tenant_id), dump(association_id)],
      [:membership_id, :actor_id]
    )
  end

  defp candidates(actor) do
    case Repo.query(
           "SELECT s.id::text,s.membership_id::text,person.display_name " <>
             @source <>
             " WHERE s.tenant_id=$1 AND " <>
             @current <>
             " AND NOT EXISTS(SELECT 1 FROM identity_staff_directory_entries d WHERE d.tenant_id=s.tenant_id AND d.association_id=s.id) AND NOT EXISTS(SELECT 1 FROM identity_accounts a WHERE a.actor_id=m.actor_id) ORDER BY s.id LIMIT 26",
           [dump(actor.tenant_id)]
         ) do
      {:ok, %{rows: rows}} ->
        {:ok,
         Enum.map(rows, fn [id, membership_id, name] ->
           %{
             association_id: id,
             membership_id: membership_id,
             display_name: name,
             reference: String.slice(id, 0, 8)
           }
         end)}

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp accounts(actor) do
    with {:ok, %{rows: [[expected]]}} <-
           Repo.query(
             "SELECT count(*) FROM identity_staff_directory_entries WHERE tenant_id=$1",
             [dump(actor.tenant_id)]
           ),
         :ok <- ensure(expected <= 25, :scope_limit),
         {:ok, %{rows: rows}} <-
           Repo.query(
             """
             SELECT d.id::text,d.account_id::text,d.association_id::text,d.actor_id::text,d.membership_id::text,
               d.given_name,d.family_name,d.display_name,a.email,d.locale,d.enabled,d.lock_version,a.status,a.temporary_password_expires_at,
               EXISTS (SELECT 1 #{@source}
                 WHERE s.tenant_id=d.tenant_id AND s.id=d.association_id AND s.membership_id=d.membership_id
                   AND m.actor_id=d.actor_id AND #{@current})
             FROM identity_staff_directory_entries d JOIN identity_accounts a ON a.id=d.account_id AND a.actor_id=d.actor_id
             WHERE d.tenant_id=$1 ORDER BY d.display_name,d.id LIMIT 26
             """,
             [dump(actor.tenant_id)]
           ),
         :ok <- ensure(length(rows) == expected, :retryable_dependency) do
      values = Enum.map(rows, &account_view(actor, &1))

      {:ok, values}
    else
      {:error, %Error{}} = failure -> failure
      _failed -> error(:retryable_dependency)
    end
  end

  defp account_view(actor, row) do
    keys = [
      :id,
      :account_id,
      :association_id,
      :actor_id,
      :membership_id,
      :given_name,
      :family_name,
      :display_name,
      :email,
      :locale,
      :enabled,
      :lock_version,
      :status,
      :temporary_password_expires_at,
      :source_current
    ]

    item = Map.new(Enum.zip(keys, row))

    {:ok, %{rows: roles}} =
      Repo.query(
        "SELECT r.id::text,r.name FROM platform_actor_role_assignments a JOIN platform_roles r ON r.id=a.role_id AND r.tenant_id=a.tenant_id WHERE a.tenant_id=$1 AND a.membership_id=$2 ORDER BY r.name,r.id LIMIT 26",
        [dump(actor.tenant_id), dump(item.membership_id)]
      )

    if length(roles) > 25, do: Repo.rollback(%Error{code: :scope_limit})

    Map.merge(item, %{
      roles: Enum.map(roles, fn [id, label] -> %{id: id, label: label} end),
      access_state: access_state(item),
      temporary_password_expires_at: iso(item.temporary_password_expires_at)
    })
  end

  defp access_state(%{source_current: false}), do: "source_unavailable"
  defp access_state(%{enabled: false}), do: "suspended"
  defp access_state(%{status: "pending_first_login"}), do: "first_login_required"
  defp access_state(%{status: "suspended"}), do: "credential_suspended"
  defp access_state(_entry), do: "enabled"

  defp entry(actor, id),
    do:
      one(
        "SELECT id::text,account_id::text,association_id::text,membership_id::text,actor_id::text,enabled,lock_version,given_name,family_name,display_name,locale FROM identity_staff_directory_entries WHERE tenant_id=$1 AND id=$2",
        [dump(actor.tenant_id), dump(id)],
        [
          :id,
          :account_id,
          :association_id,
          :membership_id,
          :actor_id,
          :enabled,
          :lock_version,
          :given_name,
          :family_name,
          :display_name,
          :locale
        ]
      )

  defp locked_entry(actor, id) do
    with {:ok, _} <-
           one(
             "SELECT id::text FROM identity_staff_directory_entries WHERE tenant_id=$1 AND id=$2 FOR UPDATE",
             [dump(actor.tenant_id), dump(id)],
             [:id]
           ),
         do: entry(actor, id)
  end

  defp own_entry(actor),
    do:
      one(
        "SELECT id::text,given_name,family_name,display_name,locale,lock_version FROM identity_staff_directory_entries WHERE tenant_id=$1 AND actor_id=$2 AND enabled=true",
        [dump(actor.tenant_id), dump(actor.actor_id)],
        [:id, :given_name, :family_name, :display_name, :locale, :lock_version]
      )

  defp inventory_capacity(actor) do
    Repo.query!(
      "SELECT pg_advisory_xact_lock(hashtextextended('staff-directory: ' || $1::text,0))",
      [actor.tenant_id]
    )

    case Repo.query("SELECT count(*) FROM identity_staff_directory_entries WHERE tenant_id=$1", [
           dump(actor.tenant_id)
         ]) do
      {:ok, %{rows: [[count]]}} -> ensure(count < 25, :scope_limit)
      _failed -> error(:retryable_dependency)
    end
  end

  defp normalize(operation, input) when is_map(input) and not is_struct(input) do
    keys = @common ++ elem(Map.fetch!(@actions, operation), 1)

    if Enum.sort(Map.keys(input)) == Enum.sort(keys),
      do: normalize_values(input),
      else: error(:invalid_input)
  end

  defp normalize_values(input) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case normalize_value(key, value) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
        _invalid -> {:halt, error(:invalid_input)}
      end
    end)
  end

  defp normalize_value(key, value)
       when key in [:id, :association_id, :profile_id, :idempotency_key, :causation_id] do
    case UUID.cast(value) do
      {:ok, id} -> {:ok, id}
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize_value(:expected_version, value) when is_integer(value) and value > 0,
    do: {:ok, value}

  defp normalize_value(:locale, value) when value in ["en", "fr", "en-MW"], do: {:ok, value}
  defp normalize_value(key, nil) when key in [:given_name, :family_name], do: {:ok, nil}

  defp normalize_value(key, value)
       when key in [:given_name, :family_name, :display_name] and is_binary(value) do
    value = String.trim(value)

    cond do
      value == "" and key != :display_name -> {:ok, nil}
      String.valid?(value) and String.length(value) in 1..200 -> {:ok, value}
      true -> error(:invalid_input)
    end
  end

  defp normalize_value(:email, value) when is_binary(value) do
    value = value |> String.trim() |> String.downcase()

    if String.valid?(value) and String.length(value) in 3..320 and
         Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/u, value),
       do: {:ok, value},
       else: error(:invalid_input)
  end

  defp normalize_value(_key, _value), do: error(:invalid_input)

  defp one(sql, params, keys) do
    case Repo.query(sql, params) do
      {:ok, %{rows: [row]}} -> {:ok, Map.new(Enum.zip(keys, row))}
      {:ok, %{rows: []}} -> error(:not_found)
      _failed -> error(:retryable_dependency)
    end
  end

  defp write(sql, params) do
    case Repo.query(sql, params) do
      {:ok, %{num_rows: 1}} ->
        :ok

      {:error, %Postgrex.Error{postgres: %{code: code}}}
      when code in [:unique_violation, :check_violation, :foreign_key_violation] ->
        error(:conflict)

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp iso(%DateTime{} = date), do: DateTime.to_iso8601(date)

  defp iso(%NaiveDateTime{} = date),
    do: date |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()

  defp iso(nil), do: nil
  defp ensure(true, _code), do: :ok
  defp ensure(false, code), do: error(code)
  defp dump(id), do: UUID.dump!(id)
  defp error(code), do: {:error, %Error{code: code}}
end
