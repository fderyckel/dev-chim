defmodule Chimwemwe.InstitutionalStructure.OperatorVerification do
  @moduledoc """
  Fresh, exactly bound synthetic operator verification and initial-impact check.

  The trusted adapter must examine its current sources on every call, including
  publication. No caller-supplied verified flag, document URL, or extra field is
  accepted. This first policy covers only a new unpublished root institution in
  the fictional ZZ jurisdiction, with no dependent records or external effects.
  Real jurisdiction policies and later impact consumers require separate review.
  """
  alias Chimwemwe.InstitutionalStructure.{Error, Runtime}
  alias Ecto.UUID

  @policy "synthetic.cf1.initial_operator.v1"
  @impact_policy "cf1.initial_unpublished_root.v1"
  @binding_keys [
    :tenant_id,
    :institutional_unit_id,
    :legal_entity_id,
    :legal_entity_version,
    :institution_version,
    :evidence_reference,
    :effective_from
  ]
  @proof_keys @binding_keys ++
                [
                  :policy_key,
                  :jurisdiction,
                  :evidence_type,
                  :evidence_version,
                  :issuer_reference,
                  :verifier_actor_id,
                  :checked_at,
                  :status_checked_on,
                  :valid_from,
                  :valid_until,
                  :conditions_satisfied,
                  :impact_policy,
                  :impact_reference,
                  :impact_accepted,
                  :consumer_keys
                ]

  @callback verify(term(), map()) :: {:ok, map()} | {:error, term()}

  @spec check(Runtime.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def check(runtime, request) do
    with {:ok, proof} when is_map(proof) <- Runtime.verify(runtime, request),
         true <- Enum.sort(Map.keys(proof)) == Enum.sort(@proof_keys),
         true <- Enum.all?(@binding_keys, &(Map.get(proof, &1) == Map.fetch!(request, &1))),
         true <- valid_policy?(proof),
         true <- valid_dates?(proof, request),
         true <- valid_references?(proof) do
      {:ok, json_proof(proof)}
    else
      _invalid -> {:error, %Error{code: :evidence_unavailable}}
    end
  rescue
    _error -> {:error, %Error{code: :evidence_unavailable}}
  catch
    :exit, _reason -> {:error, %Error{code: :evidence_unavailable}}
  end

  defp valid_policy?(proof) do
    proof.policy_key == @policy and proof.jurisdiction == "ZZ" and
      proof.evidence_type == "synthetic_operating_instrument" and
      proof.conditions_satisfied == true and proof.impact_policy == @impact_policy and
      proof.impact_accepted == true and proof.consumer_keys == []
  end

  defp valid_dates?(proof, request) do
    proof.checked_at == request.checked_at and
      match?(%Date{}, proof.status_checked_on) and match?(%Date{}, proof.valid_from) and
      match?(%Date{}, proof.valid_until) and
      Date.diff(request.local_date, proof.status_checked_on) in 0..30 and
      Date.compare(proof.valid_from, request.effective_from) != :gt and
      Date.compare(request.local_date, proof.valid_from) != :lt and
      Date.compare(proof.valid_until, request.local_date) == :gt and
      Date.compare(proof.valid_until, request.effective_from) == :gt
  end

  defp valid_references?(proof) do
    Enum.all?(
      [:evidence_version, :issuer_reference, :verifier_actor_id, :impact_reference],
      fn key ->
        match?({:ok, _uuid}, UUID.cast(Map.fetch!(proof, key)))
      end
    )
  end

  defp json_proof(proof) do
    Map.new(proof, fn
      {key, %Date{} = value} -> {Atom.to_string(key), Date.to_iso8601(value)}
      {key, %DateTime{} = value} -> {Atom.to_string(key), DateTime.to_iso8601(value)}
      {key, value} -> {Atom.to_string(key), value}
    end)
  end
end
