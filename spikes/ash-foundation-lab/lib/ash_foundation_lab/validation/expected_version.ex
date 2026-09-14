defmodule AshFoundationLab.Validation.ExpectedVersion do
  @moduledoc false

  use Ash.Resource.Validation

  alias Ash.Error.Changes.StaleRecord

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def supports(_opts), do: [Ash.Changeset]

  @impl true
  def validate(changeset, _opts, _context) do
    expected_version = Ash.Changeset.get_argument(changeset, :expected_version)

    if changeset.data.lock_version == expected_version do
      :ok
    else
      {:error, StaleRecord.exception(resource: changeset.resource, field: :lock_version)}
    end
  end
end
