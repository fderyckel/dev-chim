defmodule Mix.Tasks.Phase0.RetainedData.Measure do
  @moduledoc "Runs the disposable Phase 0 retained-data scale measurement."

  use Mix.Task

  @shortdoc "Measures the retained-data migration at the synthetic annual-school envelope"

  @switches [
    control_rows: :integer,
    output: :string,
    primary_rows: :integer,
    repetitions: :integer
  ]

  @impl Mix.Task
  def run(arguments) do
    Mix.Task.run("app.start")

    {options, remaining, invalid} = OptionParser.parse(arguments, strict: @switches)

    if remaining != [] or invalid != [] do
      Mix.raise("invalid arguments: #{inspect(remaining ++ invalid)}")
    end

    project_root = Mix.Project.project_file() |> Path.dirname()

    output_path =
      options
      |> Keyword.get(
        :output,
        "priv/maintenance/retained-data-migration-measurement.json"
      )
      |> Path.expand(project_root)

    result =
      AshFoundationLab.RetainedDataMigrationMeasurement.run!(
        primary_rows: Keyword.get(options, :primary_rows, 1_280_000),
        control_rows: Keyword.get(options, :control_rows, 32_000),
        repetitions: Keyword.get(options, :repetitions, 3),
        output_path: output_path,
        progress: true
      )

    summary = result["summary"]["primary_backfill_rows_per_second"]

    Mix.shell().info(
      "Retained-data measurement passed; primary backfill rows/s " <>
        "min/median/max=#{summary["min"]}/#{summary["median"]}/#{summary["max"]}."
    )

    Mix.shell().info("Wrote #{output_path}")
  end
end
