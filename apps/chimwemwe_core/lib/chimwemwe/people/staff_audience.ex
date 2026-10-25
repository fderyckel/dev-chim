defmodule Chimwemwe.People.StaffAudience do
  @moduledoc "Private synthetic staff source qualification; no publication or browser route."
  alias Chimwemwe.Identity.PublicRequestSession
  alias Chimwemwe.People.{Error, InternalWriter}
  alias Chimwemwe.People.StaffAudience.{Clock, Proof, Source}
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @enforce_keys [:persistence, :institution_id]
  defstruct @enforce_keys

  def new(persistence, institution_id) do
    case UUID.cast(institution_id) do
      {:ok, id} -> {:ok, %__MODULE__{persistence: persistence, institution_id: id}}
      _ -> error(:invalid_input)
    end
  end

  def capture(config, request, draft, callback \\ &{:ok, &1})

  def capture(
        %__MODULE__{} = config,
        %PublicRequestSession{support: nil} = request,
        draft,
        callback
      )
      when is_function(callback, 1) do
    with {:ok, draft_digest} <- draft_digest(draft) do
      execute(config, request, draft_digest, callback)
    end
  end

  def capture(_config, _request, _draft, _callback), do: error(:forbidden)

  defp execute(config, request, digest, callback) do
    InternalWriter.run(config.persistence, request.context, fn actor, context ->
      budget = Clock.start()

      if context.purpose != "communications.staff_audience",
        do: Repo.rollback(%Error{code: :forbidden})

      session = Source.session(request, actor)
      capture_current(config, context, actor, session, digest, callback, budget)
    end)
  end

  def recheck(config, request, draft, %Proof{} = prepared, callback \\ &{:ok, &1}) do
    capture(config, request, draft, fn current ->
      with :ok <- Clock.current_before(prepared.expires_at),
           true <- same_basis?(prepared, current) do
        callback.(current)
      else
        _ -> error(:stale)
      end
    end)
  end

  # Original intended subjects and account admission remain frozen. This is a
  # source-stage calculation only, never a notice-read authorization decision.
  def eligibility(%Proof{} = original, %Proof{} = current) do
    if original.tenant_id != current.tenant_id or
         original.institution_id != current.institution_id do
      error(:forbidden)
    else
      counts = %{
        audience: map_size(original.subjects),
        eligible: 0,
        no_eligible_account: 0,
        no_current_access: 0
      }

      {:ok,
       Enum.reduce(original.subjects, counts, fn {person, subject}, acc ->
         key = category(subject, Map.get(current.subjects, person))
         Map.update!(acc, key, &(&1 + 1))
       end)}
    end
  end

  defp capture_current(config, context, actor, session, digest, callback, budget) do
    source = Source.capture(context, config.institution_id, session)

    proof = %Proof{
      tenant_id: actor.tenant_id,
      institution_id: config.institution_id,
      actor_id: actor.actor_id,
      draft_digest: digest,
      basis_digest: hash(source.basis),
      subjects: source.subjects,
      resolved_at: source.time.now,
      expires_at: source.time.expires_at,
      local_date: source.time.date
    }

    Clock.within_budget(budget)
    result = callback.(proof)
    Clock.within_budget(budget)
    Clock.current_before(source.deadline)
    Clock.within_budget(budget)
    result
  end

  defp same_basis?(a, b) do
    a.tenant_id == b.tenant_id and a.institution_id == b.institution_id and
      a.actor_id == b.actor_id and a.draft_digest == b.draft_digest and
      a.basis_digest == b.basis_digest and a.local_date == b.local_date
  end

  defp category(_original, nil), do: :no_current_access

  defp category(%{participation_id: p}, %{participation_id: other}) when p != other,
    do: :no_current_access

  defp category(%{admission: nil}, _current), do: :no_eligible_account
  defp category(%{admission: a}, %{admission: a, eligible: true}), do: :eligible
  defp category(_original, _current), do: :no_current_access

  defp draft_digest(
         %{title: title, body: body, draft_version: version, receipt_required: receipt} = draft
       )
       when map_size(draft) == 4 and is_binary(title) and is_binary(body) and
              is_integer(version) and version > 0 and is_boolean(receipt) do
    if bounded_text?(title, 120) and bounded_text?(body, 2000) do
      {:ok, hash(draft)}
    else
      error(:invalid_input)
    end
  end

  defp draft_digest(_draft), do: error(:invalid_input)

  defp bounded_text?(text, maximum),
    do:
      byte_size(text) <= 4 * maximum and
        String.valid?(text) and length(String.codepoints(text)) in 1..maximum

  defp hash(value), do: :crypto.hash(:sha256, :erlang.term_to_binary(value, [:deterministic]))
  defp error(code), do: {:error, %Error{code: code}}
end
