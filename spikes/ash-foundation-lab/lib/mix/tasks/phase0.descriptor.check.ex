defmodule Mix.Tasks.Phase0.Descriptor.Check do
  @moduledoc "Checks the checked-in Phase 0 resource descriptor for drift."

  use Mix.Task

  @shortdoc "Checks the Phase 0 resource descriptor for drift"

  @impl Mix.Task
  def run(_arguments) do
    Mix.Task.run("compile")

    expected_path =
      Mix.Project.project_file()
      |> Path.dirname()
      |> Path.join("priv/resource_descriptors/foundation-record.v1.json")

    actual =
      AshFoundationLab.ResourceDescriptor.foundation_record!()
      |> AshFoundationLab.ResourceDescriptor.encode!()

    case File.read(expected_path) do
      {:ok, ^actual} ->
        Mix.shell().info("Phase 0 resource descriptor matches the checked artifact.")

      {:ok, _different} ->
        Mix.raise("Phase 0 resource descriptor drifted; review and update #{expected_path}")

      {:error, reason} ->
        Mix.raise("Cannot read Phase 0 resource descriptor #{expected_path}: #{inspect(reason)}")
    end
  end
end
