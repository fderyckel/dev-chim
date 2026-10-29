defmodule Chimwemwe.People.TestVerifier do
  @moduledoc false
  def verify(source, request) do
    Agent.get_and_update(source, fn state ->
      binding = Map.get(state.records, request.evidence_reference)

      result =
        if is_map(binding) and state.overrides != :revoked do
          {:ok,
           request
           |> Map.merge(%{
             policy: "synthetic.people.staff_account.v1",
             human_account: true,
             matched: true
           })
           |> Map.merge(binding)
           |> Map.merge(state.overrides)}
        else
          {:error, :unverified}
        end

      {result, %{state | calls: state.calls + 1}}
    end)
  end
end
