defmodule Chimwemwe.LocalBridge.Supervisor do
  @moduledoc """
  Starts the explicitly guarded local UI-1A runtime on loopback only.
  """

  use Supervisor

  alias Chimwemwe.LocalBridge.{Bootstrap, Endpoint, SessionStore, SyntheticData}
  alias Chimwemwe.Platform.PersistenceRuntime

  @runtime Chimwemwe.LocalBridge.PersistenceRuntime

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    token = Keyword.fetch!(options, :token)
    port = Keyword.fetch!(options, :port)
    repository_options = Keyword.fetch!(options, :repository_options)
    start_endpoint? = Keyword.get(options, :start_endpoint?, true)
    additional_sessions = Keyword.get(options, :additional_sessions, [])

    children = [
      {PersistenceRuntime,
       name: @runtime,
       repositories: [ui1_local: repository_options],
       placements: SyntheticData.placements(),
       per_tenant_limit: 4,
       per_placement_limit: 8},
      {SessionStore,
       sessions: [{token, SyntheticData.authorized_session()} | additional_sessions]},
      {Bootstrap, runtime: @runtime}
    ]

    children =
      if start_endpoint? do
        children ++
          [
            {Endpoint,
             http: [ip: {127, 0, 0, 1}, port: port],
             secret_key_base: Base.encode64(:crypto.strong_rand_bytes(48)),
             server: true}
          ]
      else
        children
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
