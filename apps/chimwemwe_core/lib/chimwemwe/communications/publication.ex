defmodule Chimwemwe.Communications.Publication do
  @moduledoc "Bounded local synthetic staff publication; ADR 0056."
  alias Chimwemwe.Communications.{Error, Evidence, InternalWriter, LocalRequestGate}
  alias Chimwemwe.Identity.PublicRequestSession
  alias Chimwemwe.People.{Foundation, StaffAudience}
  alias Chimwemwe.People.StaffAudience.{Clock, Proof, Source}
  alias Chimwemwe.Platform.{Authority, ModuleLifecycle, TrustedActor}
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID
  @module "communications.core"
  @aggregate "communications.core.notice"
  @statement "I acknowledge receipt of this notice."
  @enforce_keys [:persistence, :tenant_id, :institution_id, :institution_label, :audience]
  defstruct @enforce_keys ++ [request_gate: nil]

  def new(persistence, tenant, institution, label, request_gate \\ nil) do
    with {:ok, tenant} <- UUID.cast(tenant),
         {:ok, institution} <- UUID.cast(institution),
         true <- is_binary(label) and byte_size(label) in 1..160,
         true <- is_nil(request_gate) or is_pid(request_gate),
         {:ok, audience} <- StaffAudience.new(persistence, institution) do
      {:ok,
       %__MODULE__{
         persistence: persistence,
         tenant_id: tenant,
         institution_id: institution,
         institution_label: label,
         audience: audience,
         request_gate: request_gate
       }}
    else
      _ -> error(:invalid_input)
    end
  end

  def release_manifest do
    {:ok, manifest} =
      ReleaseManifest.new(
        ReleaseManifest.declarations(Foundation.release_manifest()) ++
          [
            %{
              key: @module,
              version: "1.0.0",
              owner: "Staff communications",
              dependencies: ["people.core"]
            }
          ]
      )

    manifest
  end

  def workspace(config, request) do
    run(config, request, "draft", fn _actor ->
      {:ok, %{institution: config.institution_label, classification: "Restricted"}}
    end)
  end

  def create_draft(config, request, input) do
    with :ok <- schema(input, [:title, :body, :receipt_required]),
         :ok <- content(input) do
      run(config, request, "draft", &create_draft_current(config, request, &1, input))
    end
  end

  def revise_draft(config, request, input) do
    with :ok <- schema(input, [:notice_id, :expected_version, :title, :body, :receipt_required]),
         :ok <- target(input),
         :ok <- content(input) do
      run(config, request, "draft", &revise_draft_current(config, request, &1, input))
    end
  end

  def prepare_operation(config, request, input) do
    with :ok <- schema(input, [:notice_id, :expected_version, :operation, :title, :body, :reason]),
         :ok <- target(input),
         true <- input.operation in ["publish", "correct", "withdraw"],
         true <- text?(input.title, 120) and text?(input.body, 2000) and reason?(input) do
      run(config, request, "draft", &prepare_operation_current(config, request, &1, input))
    else
      false -> error(:invalid_input)
      other -> other
    end
  end

  def submit_for_approval(config, request, input) do
    with :ok <- schema(input, [:notice_id, :expected_version, :preparation_id]),
         :ok <- target(input),
         :ok <- uuid(input.preparation_id) do
      run(config, request, "draft", &submit_for_approval_current(config, request, &1, input))
    end
  end

  def approve_operation(config, request, input) do
    with :ok <- schema(input, [:notice_id, :expected_version, :preparation_id]),
         :ok <- target(input),
         :ok <- uuid(input.preparation_id) do
      run(config, request, "approve", &approve_operation_current(config, request, &1, input))
    end
  end

  def inspect_draft(config, request, id) do
    with :ok <- uuid(id) do
      run(config, request, "draft", &inspect_draft_current(config, request, &1, id))
    end
  end

  def review_operation(config, request, id) do
    with :ok <- uuid(id) do
      run(config, request, "approve", &review_operation_current(config, request, &1, id))
    end
  end

  def open_notice(config, request, input) do
    engage(config, request, input, "opening")
  end

  def confirm_receipt(config, request, input) do
    engage(config, request, input, "receipt")
  end

  defp engage(config, request, input, kind) do
    with :ok <- schema(input, [:notice_id, :revision_id]),
         :ok <- uuid(input.notice_id),
         :ok <- uuid(input.revision_id) do
      run(config, request, "read", &engage_current(config, request, &1, input, kind), :recipient)
    end
  end

  def recipient_status(config, request, id) do
    with :ok <- uuid(id) do
      run(config, request, "read", &recipient_status_current(config, request, &1, id), :recipient)
    end
  end

  def metrics(config, request, id, revision_id) do
    with :ok <- uuid(id), :ok <- uuid(revision_id) do
      run(config, request, "metrics", &metrics_current(config, request, &1, id, revision_id))
    end
  end

  def inspect_own_receipt(config, request, id, revision_id) do
    with :ok <- uuid(id), :ok <- uuid(revision_id) do
      run(
        config,
        request,
        "read",
        &inspect_own_receipt_current(config, request, &1, id, revision_id),
        :recipient
      )
    end
  end

  def command_outcome(config, request, input) do
    with :ok <- exact(input, [:notice_id, :action, :idempotency_key]),
         :ok <- outcome_target(input),
         :ok <- uuid(input.idempotency_key),
         true <- input.action in actions() do
      capability = capability(input.action)
      run(config, request, capability, &command_outcome_current(config, request, &1, input))
    else
      false -> error(:invalid_input)
      other -> other
    end
  end

  defp outcome_target(%{action: "create_draft", notice_id: nil}) do
    :ok
  end

  defp outcome_target(input) do
    uuid(input.notice_id)
  end

  defp resolve_outcome_target!(actor, %{action: "create_draft", notice_id: nil} = input) do
    case Repo.query!(
           """
           SELECT aggregate_id::text,actor_id::text FROM platform_authority_action_idempotency
           WHERE tenant_id=$1 AND action_name='communications.core.create_draft' AND idempotency_key=$2
           """,
           [dump(actor.tenant_id), dump(input.idempotency_key)]
         ).rows do
      [[id, who]] when who == actor.actor_id -> id
      [] -> nil
      _ -> fail(:forbidden)
    end
  end

  defp resolve_outcome_target!(_actor, input) do
    input.notice_id
  end

  defp authorize_outcome(config, request, actor, input, callback) do
    if capability(input.action) == "read" do
      recipient(config, request, actor, input.notice_id, fn _notice, _revision, _person ->
        callback.()
      end)
    else
      notice = notice!(actor, config, input.notice_id)

      if input.action in ["create_draft", "revise_draft"] do
        own_draft!(notice, actor)
      end

      callback.()
    end
  end

  defp recipient(config, request, actor, id, callback) do
    original = original_for_notice!(actor, config, id)

    StaffAudience.with_recipient(
      config.audience,
      request,
      original,
      fn context -> authorize!(context, "read") end,
      fn person ->
        notice = notice!(actor, config, id)
        revision = current_revision!(actor, notice)
        callback.(notice, revision, person)
      end
    )
  end

  defp run(config, request, capability, operation, session_owner \\ :communications)

  defp run(
         %__MODULE__{} = config,
         %PublicRequestSession{support: nil} = request,
         capability,
         operation,
         session_owner
       ) do
    LocalRequestGate.with_slot(
      config.request_gate,
      config.tenant_id,
      config.institution_id,
      fn -> run_writer(config, request, capability, operation, session_owner) end
    )
  end

  defp run(_config, _request, _capability, _operation, _session_owner), do: error(:forbidden)

  defp run_writer(config, request, capability, operation, session_owner) do
    InternalWriter.run(config.persistence, request.context, fn actor, context ->
      if actor.tenant_id != config.tenant_id or context.purpose != "communications.staff_audience" do
        fail(:forbidden)
      end

      budget = Clock.start()

      deadline =
        if session_owner == :recipient,
          do: Source.observe_session_deadline(request, actor),
          else: Source.session(config.persistence, request, actor).deadline

      Clock.bound(deadline)
      if session_owner != :recipient, do: authorize!(context, capability)

      case operation.(Map.put(actor, :institution_id, config.institution_id)) do
        {:ok, _value} = result ->
          Clock.within_budget(budget)
          Clock.current_before(deadline)
          result

        {:error, _reason} = error ->
          error
      end
    end)
  end

  defp authorize!(context, capability) do
    case ModuleLifecycle.authorize_current_transaction(
           release_manifest(),
           context,
           @module,
           @module <> ".notices." <> capability
         ) do
      :ok -> :ok
      {:error, %{code: code}} -> fail(code)
      _ -> fail(:forbidden)
    end
  end

  defp apply_approved(actor, notice, prepared, current) do
    if prepared.operation == "withdraw" do
      Repo.query!(
        """
        UPDATE communications_notices SET state='withdrawn',lock_version=lock_version+1
        WHERE tenant_id=$1 AND id=$2
        """,
        [dump(actor.tenant_id), dump(notice.id)]
      )

      {:ok, %{notice_id: notice.id, version: notice.version + 1, state: "withdrawn"}}
    else
      number = notice.number + 1

      if number > 2 do
        fail(:scope_limit)
      end

      id = UUID.generate()
      original = original!(actor, notice, current)
      {:ok, eligibility} = StaffAudience.eligibility(original, current)

      unless eligibility == prepared.eligibility do
        fail(:stale)
      end

      Repo.query!(
        """
        INSERT INTO communications_revisions
          (id,tenant_id,notice_id,preparation_id,number,proposer_id,approver_id,title,body,reason,
           receipt_required,original_proof,eligibility,published_at,inserted_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,clock_timestamp() AT TIME ZONE 'UTC',NOW())
        """,
        [
          dump(id),
          dump(actor.tenant_id),
          dump(notice.id),
          dump(prepared.id),
          number,
          dump(prepared.proposer),
          dump(actor.actor_id),
          prepared.title,
          prepared.body,
          prepared.reason,
          prepared.receipt,
          encode(original),
          eligibility
        ]
      )

      Repo.query!(
        """
        UPDATE communications_notices SET state='published',lock_version=lock_version+1,
          current_revision_number=$3,submitted_preparation_id=NULL WHERE tenant_id=$1 AND id=$2
        """,
        [dump(actor.tenant_id), dump(notice.id), number]
      )

      {:ok,
       %{
         notice_id: notice.id,
         revision_id: id,
         number: number,
         version: notice.version + 1,
         state: "published"
       }}
    end
  end

  defp authorize_proposer!(actor, prepared) do
    rows =
      Repo.query!(
        "SELECT id FROM platform_tenant_memberships WHERE tenant_id=$1 AND id=$2 AND actor_id=$3",
        [dump(actor.tenant_id), dump(prepared.membership), dump(prepared.proposer)]
      ).rows

    {:ok, trusted} =
      TrustedActor.establish(
        actor_id: prepared.proposer,
        tenant_id: actor.tenant_id,
        assurance: "authenticated"
      )

    unless rows != [] and Authority.actor_has_capability?(trusted, @module <> ".notices.draft") do
      fail(:forbidden)
    end
  end

  defp prepare_allowed!(notice, actor, input) do
    if notice.state == "withdrawn", do: fail(:conflict)
    operation_allowed!(input.operation, notice, actor, input)
  end

  defp operation_allowed!("publish", notice, actor, input) do
    own_draft!(notice, actor)

    if notice.number != 0 or notice.title != input.title or notice.body != input.body,
      do: fail(:conflict)
  end

  defp operation_allowed!("correct", notice, _actor, _input),
    do: if(notice.number != 1, do: fail(:scope_limit))

  defp operation_allowed!("withdraw", notice, actor, input) do
    if notice.number == 0, do: fail(:conflict)
    revision = current_revision!(actor, notice)
    if revision.title != input.title or revision.body != input.body, do: fail(:conflict)
  end

  defp original!(_actor, %{number: 0}, current) do
    current
  end

  defp original!(actor, notice, _current) do
    current_revision!(actor, notice).proof
  end

  defp original_for_notice!(actor, config, id) do
    case Repo.query!(
           """
           SELECT r.original_proof FROM communications_revisions r JOIN communications_notices n
           ON n.id=r.notice_id AND n.tenant_id=r.tenant_id
           WHERE n.tenant_id=$1 AND n.institution_id=$2 AND n.id=$3 AND r.number=1
           """,
           [dump(actor.tenant_id), dump(config.institution_id), dump(id)]
         ).rows do
      [[proof]] -> decode(proof)
      _ -> fail(:forbidden)
    end
  end

  defp notice!(actor, config, id) do
    case Repo.query!(
           """
           SELECT id::text,author_id::text,title,body,receipt_required,state,lock_version,current_revision_number,
             submitted_preparation_id::text FROM communications_notices
           WHERE tenant_id=$1 AND institution_id=$2 AND id=$3 FOR UPDATE
           """,
           [dump(actor.tenant_id), dump(config.institution_id), dump(id)]
         ).rows do
      [[id, author, title, body, receipt, state, version, number, pending]] ->
        %{
          id: id,
          author: author,
          title: title,
          body: body,
          receipt: receipt,
          state: state,
          version: version,
          number: number,
          pending: pending
        }

      _ ->
        fail(:forbidden)
    end
  end

  defp preparation_for_notice!(actor, config, id, prepared) do
    case Repo.query!(
           """
           SELECT p.id::text FROM communications_preparations p JOIN communications_notices n
             ON n.id=p.notice_id AND n.tenant_id=p.tenant_id
           WHERE n.tenant_id=$1 AND n.institution_id=$2 AND n.id=$3 AND p.id=$4
           """,
           [dump(actor.tenant_id), dump(config.institution_id), dump(id), dump(prepared)]
         ).rows do
      [[_]] -> preparation!(actor, %{id: id}, prepared)
      _ -> fail(:forbidden)
    end
  end

  defp preparation!(actor, notice, id) do
    case Repo.query!(
           """
           SELECT id::text,proposer_id::text,base_version,operation,title,body,reason,receipt_required,
             expected_revision_number,source_proof,eligibility,expires_at,proposer_membership_id::text FROM communications_preparations
           WHERE tenant_id=$1 AND notice_id=$2 AND id=$3
           """,
           [dump(actor.tenant_id), dump(notice.id), dump(id)]
         ).rows do
      [
        [
          id,
          proposer,
          base,
          operation,
          title,
          body,
          reason,
          receipt,
          number,
          proof,
          eligibility,
          expiry,
          membership
        ]
      ] ->
        %{
          id: id,
          proposer: proposer,
          base: base,
          operation: operation,
          title: title,
          body: body,
          reason: reason,
          receipt: receipt,
          number: number,
          proof: decode(proof),
          eligibility: atom_counts(eligibility),
          expires_at: expiry,
          membership: membership
        }

      _ ->
        fail(:forbidden)
    end
  end

  defp current_revision!(actor, notice) do
    case Repo.query!(
           "SELECT id::text FROM communications_revisions WHERE tenant_id=$1 AND notice_id=$2 AND number=$3",
           [dump(actor.tenant_id), dump(notice.id), notice.number]
         ).rows do
      [[id]] -> revision!(actor, notice, id)
      _ -> fail(:forbidden)
    end
  end

  defp revision!(actor, notice, id) do
    case Repo.query!(
           """
           SELECT id::text,number,title,body,reason,receipt_required,original_proof,eligibility,published_at
           FROM communications_revisions WHERE tenant_id=$1 AND notice_id=$2 AND id=$3
           """,
           [dump(actor.tenant_id), dump(notice.id), dump(id)]
         ).rows do
      [[id, number, title, body, reason, receipt, proof, eligibility, time]] ->
        %{
          id: id,
          number: number,
          title: title,
          body: body,
          reason: reason,
          receipt: receipt,
          proof: decode(proof),
          eligibility: atom_counts(eligibility),
          published_at: time
        }

      _ ->
        fail(:forbidden)
    end
  end

  defp own_receipt(actor, revision, person) do
    case Repo.query!(
           """
           SELECT id::text,recorded_at FROM communications_engagements
           WHERE tenant_id=$1 AND revision_id=$2 AND person_id=$3 AND kind='receipt'
           """,
           [dump(actor.tenant_id), dump(revision.id), dump(person)]
         ).rows do
      [[id, time]] ->
        %{
          receipt_id: id,
          revision_id: revision.id,
          statement: @statement,
          recorded_at: NaiveDateTime.to_iso8601(time),
          status: "confirmed"
        }

      [] ->
        nil
    end
  end

  defp existing_fact([], actor, revision, person, kind) do
    Repo.query!(
      """
      SELECT id::text,recorded_at FROM communications_engagements
      WHERE tenant_id=$1 AND revision_id=$2 AND person_id=$3 AND kind=$4
      """,
      [dump(actor.tenant_id), dump(revision.id), dump(person), kind]
    ).rows
  end

  defp existing_fact(rows, _actor, _revision, _person, _kind) do
    rows
  end

  defp command(actor, name, input, aggregate, operation) do
    with {:ok, result, _disposition} <-
           command_with_replay(actor, name, input, aggregate, operation),
         do: {:ok, result}
  end

  defp command_with_replay(actor, name, input, aggregate, operation) do
    hash = digest({actor.institution_id, input})

    with {:ok, claim} <-
           Evidence.claim(actor, action(name), @aggregate, input.idempotency_key, hash, aggregate) do
      complete_command(claim, actor, name, input, aggregate, hash, operation)
    end
  end

  defp complete_command({:existing, stored}, actor, _name, _input, _aggregate, hash, _operation) do
    with {:ok, replay} <- Evidence.replay(stored, actor.actor_id, hash),
         do: {:ok, result_payload(replay.result_payload), :replayed}
  end

  defp complete_command({:new, id}, actor, name, input, aggregate, _hash, operation) do
    with {:ok, result} <- operation.(aggregate),
         {:ok, _} <-
           Evidence.record(actor, %{
             action_name: action(name),
             aggregate_type: @aggregate,
             aggregate_id: aggregate,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: Map.get(input, :expected_version, 0),
             after_version: Map.get(result, :version, 1),
             change_summary: Map.merge(%{"action" => name}, Map.take(input, [:preparation_id])),
             event_type: action(name) <> ".completed",
             event_payload: %{"notice_id" => aggregate},
             result_payload: result,
             claim_id: id
           }) do
      {:ok, result, :new}
    end
  end

  defp summary(config, notice) do
    %{
      notice_id: notice.id,
      version: notice.version,
      state: notice.state,
      number: notice.number,
      institution: config.institution_label,
      classification: "Restricted"
    }
  end

  defp published_state(%{state: "pending", number: number}) when number > 0, do: "published"
  defp published_state(notice), do: notice.state

  defp recipient_summary(config, notice),
    do: Map.put(summary(config, notice), :state, published_state(notice))

  defp result_payload(payload) do
    keys = [
      :notice_id,
      :institution,
      :classification,
      :revision_id,
      :preparation_id,
      :fact_id,
      :version,
      :number,
      :state,
      :expires_at,
      :eligibility,
      :recorded_at,
      :kind
    ]

    Map.new(Enum.filter(keys, &Map.has_key?(payload, Atom.to_string(&1))), fn key ->
      value = Map.fetch!(payload, Atom.to_string(key))

      {key,
       if key == :eligibility do
         atom_counts(value)
       else
         value
       end}
    end)
  end

  defp content_view(config, notice, revision) do
    Map.merge(recipient_summary(config, notice), %{
      revision_id: revision.id,
      title: revision.title,
      body: revision.body,
      reason: revision.reason,
      receipt_required: revision.receipt,
      statement: @statement,
      published_at: NaiveDateTime.to_iso8601(revision.published_at)
    })
  end

  defp own_draft!(notice, actor) do
    if notice.author != actor.actor_id do
      fail(:forbidden)
    end
  end

  defp expected!(notice, input) do
    if notice.version != input.expected_version do
      fail(:stale)
    end
  end

  defp lock_institution(actor, config) do
    Repo.query!("SELECT pg_advisory_xact_lock(hashtextextended($1,0))", [
      "communications-institution:" <> actor.tenant_id <> ":" <> config.institution_id
    ])
  end

  defp same_source?(a, b) do
    a.tenant_id == b.tenant_id and a.institution_id == b.institution_id and
      a.basis_digest == b.basis_digest and a.draft_digest == b.draft_digest and
      a.local_date == b.local_date
  end

  defp encode(%Proof{} = proof) do
    :erlang.term_to_binary(proof, [:deterministic])
  end

  defp decode(value) do
    case :erlang.binary_to_term(value, [:safe]) do
      %Proof{} = proof -> proof
      _ -> fail(:retryable_dependency)
    end
  end

  defp atom_counts(counts) do
    Map.new(
      [:audience, :eligible, :no_eligible_account, :no_current_access],
      fn key -> {key, Map.fetch!(counts, Atom.to_string(key))} end
    )
  end

  defp digest(value) do
    :crypto.hash(:sha256, :erlang.term_to_binary(value, [:deterministic]))
  end

  defp action(name) do
    @module <> "." <> name
  end

  defp actions do
    [
      "create_draft",
      "revise_draft",
      "prepare_operation",
      "submit_for_approval",
      "approve_operation",
      "open_notice",
      "confirm_receipt"
    ]
  end

  defp capability("approve_operation") do
    "approve"
  end

  defp capability(name) when name in ["open_notice", "confirm_receipt"] do
    "read"
  end

  defp capability(_name) do
    "draft"
  end

  defp schema(input, keys) do
    with :ok <- exact(input, keys ++ [:idempotency_key, :causation_id]),
         :ok <- uuid(input.idempotency_key) do
      uuid(input.causation_id)
    end
  end

  defp exact(input, keys) when is_map(input) and not is_struct(input) do
    if Enum.sort(Map.keys(input)) == Enum.sort(keys) do
      :ok
    else
      error(:invalid_input)
    end
  end

  defp exact(_input, _keys) do
    error(:invalid_input)
  end

  defp target(input) do
    with :ok <- uuid(input.notice_id),
         true <- is_integer(input.expected_version) and input.expected_version > 0 do
      :ok
    else
      _ -> error(:invalid_input)
    end
  end

  defp content(input) do
    if text?(input.title, 120) and text?(input.body, 2000) and is_boolean(input.receipt_required) do
      :ok
    else
      error(:invalid_input)
    end
  end

  defp reason?(%{operation: "publish", reason: ""}) do
    true
  end

  defp reason?(%{operation: operation, reason: reason})
       when operation in ["correct", "withdraw"] do
    text?(reason, 240)
  end

  defp reason?(_) do
    false
  end

  defp text?(value, max) do
    is_binary(value) and byte_size(value) <= max * 4 and String.valid?(value) and
      String.trim(value) != "" and length(String.codepoints(value)) <= max
  end

  defp uuid(value) do
    if match?({:ok, _}, UUID.cast(value)) do
      :ok
    else
      error(:invalid_input)
    end
  end

  defp dump(value) do
    UUID.dump!(value)
  end

  defp fail(code) do
    Repo.rollback(%Error{code: code})
  end

  defp error(code) do
    {:error, %Error{code: code}}
  end

  defp create_draft_current(config, _request, actor, input) do
    lock_institution(actor, config)

    command(actor, "create_draft", input, UUID.generate(), fn id ->
      [[count]] =
        Repo.query!(
          "SELECT count(*) FROM communications_notices WHERE tenant_id=$1 AND institution_id=$2",
          [dump(actor.tenant_id), dump(config.institution_id)]
        ).rows

      if count >= 5 do
        fail(:scope_limit)
      end

      Repo.query!(
        """
        INSERT INTO communications_notices
          (id,tenant_id,institution_id,author_id,title,body,receipt_required,state,lock_version,current_revision_number,inserted_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,'draft',1,0,NOW())
        """,
        [
          dump(id),
          dump(actor.tenant_id),
          dump(config.institution_id),
          dump(actor.actor_id),
          input.title,
          input.body,
          input.receipt_required
        ]
      )

      {:ok,
       %{
         notice_id: id,
         version: 1,
         state: "draft",
         institution: config.institution_label,
         classification: "Restricted"
       }}
    end)
  end

  defp revise_draft_current(config, _request, actor, input) do
    notice = notice!(actor, config, input.notice_id)
    own_draft!(notice, actor)

    command(actor, "revise_draft", input, notice.id, fn _ ->
      expected!(notice, input)

      if notice.number != 0 or notice.state == "withdrawn" do
        fail(:conflict)
      end

      Repo.query!(
        """
        UPDATE communications_notices SET title=$3,body=$4,receipt_required=$5,state='draft',
          submitted_preparation_id=NULL,lock_version=lock_version+1 WHERE tenant_id=$1 AND id=$2
        """,
        [dump(actor.tenant_id), dump(notice.id), input.title, input.body, input.receipt_required]
      )

      {:ok, %{notice_id: notice.id, version: notice.version + 1, state: "draft"}}
    end)
  end

  defp prepare_operation_current(config, request, actor, input) do
    draft = %{
      title: input.title,
      body: input.body,
      draft_version: input.expected_version,
      receipt_required: false
    }

    StaffAudience.capture(
      config.audience,
      request,
      draft,
      &prepare_captured(config, request, actor, input, draft, &1)
    )
  end

  defp submit_for_approval_current(config, _request, actor, input) do
    notice = notice!(actor, config, input.notice_id)
    prepared = preparation!(actor, notice, input.preparation_id)

    if prepared.proposer != actor.actor_id do
      fail(:forbidden)
    end

    command(actor, "submit_for_approval", input, notice.id, fn _ ->
      expected!(notice, input)

      if prepared.base != notice.version do
        fail(:stale)
      end

      Clock.current_before(prepared.expires_at)

      if notice.state == "withdrawn" do
        fail(:conflict)
      end

      Repo.query!(
        """
        UPDATE communications_notices SET state='pending',submitted_preparation_id=$3,
          lock_version=lock_version+1 WHERE tenant_id=$1 AND id=$2
        """,
        [dump(actor.tenant_id), dump(notice.id), dump(prepared.id)]
      )

      {:ok,
       %{
         notice_id: notice.id,
         version: notice.version + 1,
         state: "pending",
         preparation_id: prepared.id
       }}
    end)
  end

  defp approve_operation_current(config, request, actor, input) do
    prepared = preparation_for_notice!(actor, config, input.notice_id, input.preparation_id)

    if prepared.proposer == actor.actor_id do
      fail(:forbidden)
    end

    draft = %{
      title: prepared.title,
      body: prepared.body,
      draft_version: prepared.base,
      receipt_required: prepared.receipt
    }

    StaffAudience.capture_for_approval(
      config.audience,
      request,
      draft,
      prepared.membership,
      &approve_captured(config, request, actor, input, prepared, &1)
    )
  end

  defp inspect_draft_current(config, _request, actor, id) do
    notice = notice!(actor, config, id)
    if notice.number == 0, do: own_draft!(notice, actor)

    cond do
      notice.state == "withdrawn" ->
        {:ok, summary(config, notice)}

      notice.number > 0 ->
        revision = current_revision!(actor, notice)

        {:ok,
         Map.merge(summary(config, notice), %{
           title: revision.title,
           body: revision.body,
           receipt_required: notice.receipt
         })}

      true ->
        {:ok,
         Map.merge(summary(config, notice), %{
           title: notice.title,
           body: notice.body,
           receipt_required: notice.receipt
         })}
    end
  end

  defp review_operation_current(config, _request, actor, id) do
    notice = notice!(actor, config, id)

    cond do
      notice.state == "withdrawn" ->
        {:ok, summary(config, notice)}

      notice.state == "pending" and not is_nil(notice.pending) ->
        review_pending(config, actor, notice)

      notice.number > 0 ->
        {:ok, content_view(config, notice, current_revision!(actor, notice))}

      true ->
        error(:conflict)
    end
  end

  defp review_pending(config, actor, notice) do
    prepared = preparation!(actor, notice, notice.pending)

    if prepared.proposer == actor.actor_id do
      fail(:forbidden)
    end

    {:ok,
     Map.merge(summary(config, notice), %{
       preparation_id: prepared.id,
       operation: prepared.operation,
       title: prepared.title,
       body: prepared.body,
       reason: prepared.reason,
       receipt_required: prepared.receipt,
       eligibility: prepared.eligibility,
       expires_at: NaiveDateTime.to_iso8601(prepared.expires_at)
     })}
  end

  defp engage_current(config, request, actor, input, kind) do
    recipient(
      config,
      request,
      actor,
      input.notice_id,
      &engage_recipient(config, actor, input, kind, &1, &2, &3)
    )
  end

  defp recipient_status_current(config, request, actor, id) do
    recipient(config, request, actor, id, &status_recipient(config, actor, &1, &2, &3))
  end

  defp metrics_current(config, _request, actor, id, revision_id) do
    notice = notice!(actor, config, id)
    revision = revision!(actor, notice, revision_id)

    [[opened, confirmed, now]] =
      Repo.query!(
        """
        SELECT count(*) FILTER (WHERE kind='opening'),count(*) FILTER (WHERE kind='receipt'),
          clock_timestamp() AT TIME ZONE 'UTC' FROM communications_engagements
        WHERE tenant_id=$1 AND notice_id=$2 AND revision_id=$3
        """,
        [dump(actor.tenant_id), dump(notice.id), dump(revision.id)]
      ).rows

    {:ok,
     %{
       notice_id: notice.id,
       revision_id: revision.id,
       institution: config.institution_label,
       state: published_state(notice),
       published_at: NaiveDateTime.to_iso8601(revision.published_at),
       metrics_as_of: NaiveDateTime.to_iso8601(now),
       receipt_required: revision.receipt,
       eligibility: revision.eligibility,
       opened: opened,
       receipt_confirmed: confirmed
     }}
  end

  defp inspect_own_receipt_current(config, request, actor, id, revision_id) do
    recipient(config, request, actor, id, &own_receipt_view(actor, revision_id, &1, &2, &3))
  end

  defp command_outcome_current(config, request, actor, input) do
    resolved = resolve_outcome_target!(actor, input)

    if is_nil(resolved),
      do: {:ok, %{status: "not_recorded"}},
      else:
        authorize_outcome(config, request, actor, %{input | notice_id: resolved}, fn ->
          outcome_result(actor, input, resolved)
        end)
  end

  defp outcome_result(actor, input, resolved) do
    rows =
      Repo.query!(
        """
        SELECT actor_id::text,result_payload,status FROM platform_authority_action_idempotency
        WHERE tenant_id=$1 AND action_name=$2 AND idempotency_key=$3 AND aggregate_id=$4
        """,
        [dump(actor.tenant_id), action(input.action), dump(input.idempotency_key), dump(resolved)]
      ).rows

    case rows do
      [[who, result, "completed"]] when who == actor.actor_id ->
        {:ok, %{status: "committed", result: result}}

      [] ->
        {:ok, %{status: "not_recorded"}}

      _ ->
        error(:forbidden)
    end
  end

  defp prepare_captured(config, request, actor, input, draft, proof) do
    notice = notice!(actor, config, input.notice_id)

    command(actor, "prepare_operation", input, notice.id, fn _ ->
      expected!(notice, input)
      prepare_allowed!(notice, actor, input)
      original = original!(actor, notice, proof)
      {:ok, eligibility} = StaffAudience.eligibility(original, proof)

      prepared = %{
        proof
        | draft_digest:
            digest(%{draft | receipt_required: notice.receipt, draft_version: notice.version + 1})
      }

      id = UUID.generate()

      Repo.query!(
        """
        INSERT INTO communications_preparations
          (id,tenant_id,notice_id,proposer_id,base_version,operation,title,body,reason,
           receipt_required,expected_revision_number,source_proof,eligibility,expires_at,proposer_membership_id,inserted_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,NOW())
        """,
        [
          dump(id),
          dump(actor.tenant_id),
          dump(notice.id),
          dump(actor.actor_id),
          notice.version + 1,
          input.operation,
          input.title,
          input.body,
          input.reason,
          notice.receipt,
          notice.number,
          encode(prepared),
          eligibility,
          proof.expires_at,
          dump(request.session.membership_id)
        ]
      )

      state =
        if notice.number == 0 do
          "draft"
        else
          "published"
        end

      Repo.query!(
        "UPDATE communications_notices SET lock_version=lock_version+1,state=$3,submitted_preparation_id=NULL WHERE tenant_id=$1 AND id=$2",
        [dump(actor.tenant_id), dump(notice.id), state]
      )

      {:ok,
       %{
         notice_id: notice.id,
         preparation_id: id,
         version: notice.version + 1,
         state: state,
         expires_at: NaiveDateTime.to_iso8601(proof.expires_at),
         eligibility: eligibility
       }}
    end)
  end

  defp approve_captured(config, request, actor, input, prepared, current) do
    authorize!(request.context, "approve")
    authorize_proposer!(actor, prepared)
    notice = notice!(actor, config, input.notice_id)

    command(actor, "approve_operation", input, notice.id, fn _ ->
      expected!(notice, input)

      if notice.state != "pending" or notice.pending != prepared.id or
           notice.version != prepared.base + 1 or notice.number != prepared.number do
        fail(:stale)
      end

      Clock.current_before(prepared.expires_at)

      unless same_source?(prepared.proof, current) do
        fail(:stale)
      end

      apply_approved(actor, notice, prepared, current)
    end)
  end

  defp engage_recipient(config, actor, input, kind, notice, revision, person) do
    if notice.state == "withdrawn" or revision.id != input.revision_id do
      fail(:stale)
    end

    if kind == "receipt" and not revision.receipt do
      fail(:conflict)
    end

    action =
      if kind == "receipt" do
        "confirm_receipt"
      else
        "open_notice"
      end

    with {:ok, result, disposition} <-
           command_with_replay(
             actor,
             action,
             input,
             notice.id,
             &engagement_fact(actor, notice, revision, person, kind, &1)
           ) do
      if kind == "opening" and disposition == :new do
        {:ok, Map.merge(result, content_view(config, notice, revision))}
      else
        engagement_response(kind, result)
      end
    end
  end

  defp engagement_response("opening", result), do: {:ok, result}

  defp engagement_response("receipt", result),
    do: {:ok, Map.merge(result, %{statement: @statement, status: "confirmed"})}

  defp engagement_fact(actor, notice, revision, person, kind, _aggregate) do
    id = UUID.generate()

    statement =
      if kind == "receipt" do
        @statement
      else
        nil
      end

    [[fact, time]] =
      Repo.query!(
        """
        INSERT INTO communications_engagements
          (id,tenant_id,notice_id,revision_id,person_id,actor_id,kind,statement,recorded_at,inserted_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,clock_timestamp() AT TIME ZONE 'UTC',NOW())
        ON CONFLICT (tenant_id,revision_id,person_id,kind) DO NOTHING RETURNING id::text,recorded_at
        """,
        [
          dump(id),
          dump(actor.tenant_id),
          dump(notice.id),
          dump(revision.id),
          dump(person),
          dump(actor.actor_id),
          kind,
          statement
        ]
      ).rows
      |> existing_fact(actor, revision, person, kind)

    {:ok,
     %{
       notice_id: notice.id,
       revision_id: revision.id,
       fact_id: fact,
       recorded_at: NaiveDateTime.to_iso8601(time),
       kind: kind
     }}
  end

  defp status_recipient(config, actor, notice, revision, person) do
    own = own_receipt(actor, revision, person)

    {:ok,
     Map.merge(recipient_summary(config, notice), %{
       revision_id: revision.id,
       receipt_required: revision.receipt,
       own_receipt: own,
       collection_notice: "Openings and receipt confirmations are recorded."
     })}
  end

  defp own_receipt_view(actor, revision_id, notice, _current, person) do
    exact = revision!(actor, notice, revision_id)

    {:ok,
     %{
       notice_id: notice.id,
       revision_id: exact.id,
       own_receipt: own_receipt(actor, exact, person)
     }}
  end
end
