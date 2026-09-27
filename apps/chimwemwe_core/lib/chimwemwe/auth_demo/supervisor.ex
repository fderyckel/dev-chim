defmodule Chimwemwe.AuthDemo.Supervisor do
  @moduledoc false

  use Supervisor

  alias Chimwemwe.AuthDemo.{Bootstrap, Endpoint}

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    signing_secret = Keyword.fetch!(options, :signing_secret)

    Application.put_env(:chimwemwe_core, :identity_token_signing_secret, signing_secret)

    children = [
      {Chimwemwe.Repo, Keyword.fetch!(options, :repository_options)},
      {AshAuthentication.Supervisor, otp_app: :chimwemwe_core},
      {Bootstrap,
       password: Keyword.fetch!(options, :password),
       tenant_id: Keyword.fetch!(options, :tenant_id)},
      {Endpoint,
       http: [ip: {127, 0, 0, 1}, port: Keyword.fetch!(options, :port)],
       secret_key_base: Base.encode64(:crypto.strong_rand_bytes(48)),
       server: true}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
