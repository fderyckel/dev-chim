defmodule AshFoundationLab.RetainedDataMigrationMeasurementTest do
  use ExUnit.Case, async: false

  alias AshFoundationLab.RetainedDataMigrationMeasurement

  test "the measurement uses disposable databases and proves tenant-scoped retention" do
    result =
      RetainedDataMigrationMeasurement.run!(
        primary_rows: 200,
        control_rows: 20,
        repetitions: 1,
        output_path: nil
      )

    assert result["result"] == "measured_with_bounded_remediation"
    assert result["envelope"]["approved_production_target"] == false
    assert result["methodology"]["backfill_batch_size"] == 100

    assert [run] = result["runs"]
    assert run["rows"] == %{"primary_tenant" => 200, "control_tenant" => 20, "total" => 220}
    assert run["backfill"]["primary"]["batches"] == 2
    assert run["backfill"]["control"]["batches"] == 1
    assert Enum.all?(run["assertions"], fn {_name, passed?} -> passed? end)
    assert run["retained_fingerprint"]["rows"] == 220
    assert run["wal_bytes"]["total"] > 0
  end

  test "invalid measurement dimensions fail before a database is created" do
    assert_raise ArgumentError, ~r/primary_rows must be a positive integer/, fn ->
      RetainedDataMigrationMeasurement.run!(primary_rows: 0)
    end
  end
end
