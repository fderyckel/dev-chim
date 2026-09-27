defmodule Chimwemwe.Platform.TemporalQualification.ProjectionBoundary do
  @moduledoc false

  alias Chimwemwe.Platform.ExecutionContext

  alias Chimwemwe.Platform.TemporalQualification.{
    ActionBoundary,
    CurrentProjection,
    ProjectionResult
  }

  @keys [:aggregate_id, :module_key]
  @qualified_key ~r/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/

  def rebuild(runtime, context, input) do
    ExecutionContext.with_validated(context, fn validated ->
      with {:ok, normalized} <- ActionBoundary.normalize_keys(input, @keys),
           true <- Enum.sort(Map.keys(normalized)) == @keys,
           {:ok, aggregate_id} <- ActionBoundary.uuid(normalized.aggregate_id),
           {:ok, module_key} <-
             ActionBoundary.token(normalized.module_key, @qualified_key, 3..120) do
        ActionBoundary.run(
          runtime,
          validated,
          CurrentProjection,
          :rebuild_current,
          %{aggregate_id: aggregate_id, module_key: module_key},
          ProjectionResult
        )
      else
        {:error, _reason} = error -> error
        _invalid -> ActionBoundary.error(:invalid_input)
      end
    end)
  end
end
