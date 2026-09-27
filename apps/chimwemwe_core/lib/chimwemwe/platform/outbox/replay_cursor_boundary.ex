defmodule Chimwemwe.Platform.Outbox.ReplayCursorBoundary do
  @moduledoc false

  alias Chimwemwe.Platform.{Authority, OutboxError, Persistence, TrustedActor}
  alias Chimwemwe.Platform.Outbox.{ConsumerRegistry, ReplayCandidate, ReplayCursor, ReplayPage}
  alias Chimwemwe.Repo

  @replay_capability "platform.outbox.replay"

  @spec page(Supervisor.supervisor(), term(), ConsumerRegistry.declaration(), ReplayCursor.t()) ::
          {:ok, ReplayPage.t()} | {:error, term()}
  def page(runtime, context, declaration, cursor) do
    run_writer(runtime, context, fn ->
      if Authority.actor_has_capability?(context.actor, @replay_capability) do
        read_page(context, declaration, cursor)
      else
        outbox_error(:forbidden)
      end
    end)
  end

  defp read_page(context, declaration, cursor) do
    {types, versions} = ConsumerRegistry.event_pairs(declaration)

    case Repo.query(
           """
           SELECT event.stream_position, event.id::text, delivery.lock_version
             FROM platform_outbox_deliveries AS delivery
             JOIN platform_outbox_events AS event
               ON event.id = delivery.event_id
              AND event.tenant_id = delivery.tenant_id
             JOIN unnest($6::text[], $7::bigint[]) AS allowed(event_type, schema_version)
               ON allowed.event_type = event.event_type
              AND allowed.schema_version = event.schema_version
            WHERE delivery.tenant_id = $1
              AND delivery.consumer_key = $2
              AND delivery.status = 'dead_letter'
              AND event.routing_version = $3
              AND event.classification = 'internal'
              AND event.stream_position > $4
              AND event.stream_position <= $5
            ORDER BY event.stream_position
            LIMIT $8
           """,
           [
             Ecto.UUID.dump!(TrustedActor.tenant_id(context.actor)),
             declaration.key,
             context.placement.routing_version,
             cursor.after_cursor,
             cursor.through_cursor,
             types,
             versions,
             cursor.limit
           ]
         ) do
      {:ok, %{rows: rows}} ->
        items =
          Enum.map(rows, fn [position, event_id, lock_version] ->
            %ReplayCandidate{
              stream_position: position,
              event_id: event_id,
              expected_lock_version: lock_version
            }
          end)

        next_cursor =
          case List.last(items) do
            nil -> cursor.after_cursor
            item -> item.stream_position
          end

        {:ok,
         %ReplayPage{
           items: items,
           next_cursor: next_cursor,
           through_cursor: cursor.through_cursor
         }}

      {:error, _error} ->
        outbox_error(:retryable_dependency)
    end
  end

  defp run_writer(runtime, context, operation) do
    case Persistence.with_writer(runtime, context, operation) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, error}} -> {:error, error}
      {:ok, _unexpected} -> outbox_error(:internal)
      {:error, _reason} = error -> error
    end
  rescue
    _error -> outbox_error(:retryable_dependency)
  catch
    :exit, _reason -> outbox_error(:retryable_dependency)
  end

  defp outbox_error(code), do: {:error, %OutboxError{code: code}}
end
