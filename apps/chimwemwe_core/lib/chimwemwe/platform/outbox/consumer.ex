defmodule Chimwemwe.Platform.Outbox.Consumer do
  @moduledoc """
  Behaviour for code-owned, database-local outbox consumers.

  The callback runs inside the authoritative writer transaction. Implementations
  may make tenant-bound database changes through the current dynamic repository,
  but must not perform network, filesystem, or other non-transactional effects.
  The returned map is bounded evidence and is digested into the durable receipt.
  """

  alias Chimwemwe.Platform.ExecutionContext
  alias Chimwemwe.Platform.Outbox.Envelope

  @type failure_code :: :consumer_rejected | :invalid_contract | :retryable_dependency
  @type result :: %{optional(String.t()) => boolean() | integer() | String.t() | nil}

  @callback consume(Envelope.t(), ExecutionContext.t()) ::
              {:ok, result()} | {:error, failure_code()}
end
