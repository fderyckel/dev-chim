defmodule AshFoundationLab.BulkPrivateArgumentRegressionTest do
  use ExUnit.Case, async: true

  alias AshFoundationLab.BulkPrivateArgumentRegressionResource, as: RegressionResource

  test "user parameters cannot set a private argument during bulk update" do
    record = create_record()

    result =
      Ash.bulk_update!(
        [record],
        :relabel,
        %{"internal_reason" => "attacker-controlled"},
        strategy: [:stream],
        return_records?: true
      )

    assert [updated] = result.records
    refute updated.audit_note == "attacker-controlled"
  end

  test "user parameters cannot set a private argument during bulk destroy" do
    record = create_record()

    result =
      Ash.bulk_destroy!(
        [record],
        :archive,
        %{"internal_reason" => "attacker-controlled"},
        strategy: [:stream],
        return_records?: true
      )

    assert [destroyed] = result.records
    refute destroyed.audit_note == "attacker-controlled"
  end

  test "trusted server options can still set the private argument" do
    record = create_record()

    result =
      Ash.bulk_update!(
        [record],
        :relabel,
        %{},
        strategy: [:stream],
        private_arguments: %{internal_reason: "server-controlled"},
        return_records?: true
      )

    assert [%{audit_note: "server-controlled"}] = result.records
  end

  defp create_record do
    RegressionResource
    |> Ash.Changeset.for_create(:create, %{audit_note: "original"})
    |> Ash.create!()
  end
end
