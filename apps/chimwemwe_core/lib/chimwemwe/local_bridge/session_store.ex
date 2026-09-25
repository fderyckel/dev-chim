defmodule Chimwemwe.LocalBridge.SessionStore do
  @moduledoc """
  Holds server-owned synthetic UI-1A session bindings.

  Only token digests are retained. Browser input cannot construct or modify the
  trusted actor and placement values returned by this store.
  """

  use GenServer

  @type session :: {Chimwemwe.Platform.TrustedActor.t(), Chimwemwe.Platform.TrustedPlacement.t()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    name = Keyword.get(options, :name, __MODULE__)
    GenServer.start_link(__MODULE__, options, name: name)
  end

  @spec authenticate(GenServer.server(), term()) :: {:ok, session()} | :error
  def authenticate(server \\ __MODULE__, token) do
    GenServer.call(server, {:authenticate, token})
  catch
    :exit, _reason -> :error
  end

  @impl true
  def init(options) do
    sessions =
      options
      |> Keyword.fetch!(:sessions)
      |> Map.new(fn {token, session} -> {digest(token), session} end)

    {:ok, sessions}
  end

  @impl true
  def handle_call({:authenticate, token}, _from, sessions) when is_binary(token) do
    token_digest = digest(token)

    result =
      Enum.find_value(sessions, :error, fn {stored_digest, session} ->
        if Plug.Crypto.secure_compare(stored_digest, token_digest), do: {:ok, session}
      end)

    {:reply, result, sessions}
  end

  def handle_call({:authenticate, _token}, _from, sessions), do: {:reply, :error, sessions}

  defp digest(token), do: :crypto.hash(:sha256, token)
end
