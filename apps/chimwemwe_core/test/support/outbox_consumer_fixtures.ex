defmodule Chimwemwe.Test.OutboxConsumer do
  @moduledoc false

  @behaviour Chimwemwe.Platform.Outbox.Consumer

  @table :chimwemwe_outbox_test_consumer

  @impl true
  def consume(envelope, _context) do
    if :ets.whereis(@table) != :undefined do
      :ets.update_counter(@table, envelope.event_id, {2, 1}, {envelope.event_id, 0})
    end

    {:ok, %{"event_id" => envelope.event_id, "schema_version" => envelope.schema_version}}
  end
end

defmodule Chimwemwe.Test.RejectingOutboxConsumer do
  @moduledoc false

  @behaviour Chimwemwe.Platform.Outbox.Consumer

  @impl true
  def consume(_envelope, _context), do: raise("synthetic consumer rejection")
end

defmodule Chimwemwe.Test.InvalidOutboxConsumer do
  @moduledoc false

  @behaviour Chimwemwe.Platform.Outbox.Consumer

  @impl true
  def consume(_envelope, _context), do: {:ok, %{atom_key: :not_a_bounded_result}}
end
