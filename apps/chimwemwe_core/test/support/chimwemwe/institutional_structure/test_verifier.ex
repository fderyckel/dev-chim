defmodule Chimwemwe.InstitutionalStructure.TestVerifier do
  @moduledoc false
  @behaviour Chimwemwe.InstitutionalStructure.OperatorVerification
  @impl true
  def verify(source, request) do
    Agent.get_and_update(source, fn state ->
      binding = Map.get(state.records, request.evidence_reference)

      result =
        if is_map(binding) and state.overrides != :revoked do
          proof =
            request
            |> Map.delete(:local_date)
            |> Map.merge(%{
              policy_key: "synthetic.cf1.initial_operator.v1",
              jurisdiction: "ZZ",
              evidence_type: "synthetic_operating_instrument",
              evidence_version: Ecto.UUID.generate(),
              issuer_reference: Ecto.UUID.generate(),
              verifier_actor_id: Ecto.UUID.generate(),
              status_checked_on: request.local_date,
              valid_from: Date.add(request.local_date, -1),
              valid_until: Date.add(request.local_date, 30),
              conditions_satisfied: true,
              impact_policy: "cf1.initial_unpublished_root.v1",
              impact_reference: Ecto.UUID.generate(),
              impact_accepted: true,
              consumer_keys: []
            })
            |> Map.merge(binding)
            |> Map.merge(state.overrides)

          {:ok, proof}
        else
          {:error, :unavailable}
        end

      {result, %{state | calls: state.calls + 1}}
    end)
  end
end
