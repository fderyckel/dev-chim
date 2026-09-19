defmodule AshFoundationLab.FieldPolicyCalculationRegressionTest do
  use ExUnit.Case, async: true

  alias AshFoundationLab.FieldPolicyCalculationRegressionResource, as: RegressionResource

  test "a forbidden calculation cannot be used as a filter oracle" do
    privileged_actor = %{id: "phase0-privileged", may_read_restricted: true}
    restricted_actor = %{id: "phase0-restricted", may_read_restricted: false}

    RegressionResource
    |> Ash.Changeset.for_create(:create, %{
      public_label: "synthetic visible record",
      restricted_value: "phase0-secret-probe"
    })
    |> Ash.create!(actor: privileged_actor)

    restricted_query =
      RegressionResource
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter_input(%{
        "restricted_calculation" => %{"eq" => "phase0-secret-probe"}
      })

    assert [] = Ash.read!(restricted_query, actor: restricted_actor)
    assert [_record] = Ash.read!(restricted_query, actor: privileged_actor)
  end
end
