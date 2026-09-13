defmodule AshFoundationLab.FoundationRecordTest do
  use ExUnit.Case, async: true

  alias AshFoundationLab.FoundationRecord
  alias AshFoundationLab.Repo
  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  setup do
    owner = Sandbox.start_owner!(Repo, shared: false)
    on_exit(fn -> Sandbox.stop_owner(owner) end)

    :ok
  end

  test "tenant context scopes creates and reads" do
    tenant_a = UUID.generate()
    tenant_b = UUID.generate()

    record =
      FoundationRecord
      |> Ash.Changeset.for_create(:create, %{name: "Synthetic record"})
      |> Ash.Changeset.set_tenant(tenant_a)
      |> Ash.create!(authorize?: true)

    assert record.tenant_id == tenant_a

    assert [visible_record] =
             FoundationRecord
             |> Ash.Query.set_tenant(tenant_a)
             |> Ash.read!(authorize?: true)

    assert visible_record.id == record.id

    assert [] ==
             FoundationRecord
             |> Ash.Query.set_tenant(tenant_b)
             |> Ash.read!(authorize?: true)
  end

  test "a missing tenant fails closed for reads" do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(FoundationRecord, authorize?: true)
    end
  end

  test "a missing tenant fails closed for creates" do
    assert_raise Ash.Error.Invalid, fn ->
      FoundationRecord
      |> Ash.Changeset.for_create(:create, %{name: "Unscoped record"})
      |> Ash.create!(authorize?: true)
    end
  end

  test "the database rejects an empty name through an alternate write" do
    assert_raise PostgrexError, fn ->
      SQL.query!(
        Repo,
        """
        INSERT INTO foundation_records (id, tenant_id, name, inserted_at, updated_at)
        VALUES ($1, $2, '', NOW(), NOW())
        """,
        [UUID.dump!(UUID.generate()), UUID.dump!(UUID.generate())]
      )
    end
  end
end
