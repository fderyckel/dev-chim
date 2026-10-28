defmodule Chimwemwe.Platform.DependencySecurityTest.Probe do
  @moduledoc false

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform.DependencySecurityTest.Domain,
    data_layer: AshPostgres.DataLayer,
    validate_domain_inclusion?: false,
    ownership: :tenant_owned

  postgres do
    schema("pg_temp")
    table "dependency_security_probes"
    repo(Chimwemwe.Repo)
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  actions do
    create :store_probe do
      accept [:id, :reference, :payload]
      upsert? true
    end

    read :inspect_probes
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id, public?: true, writable?: true

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :reference, :string do
      allow_nil? false
      public? true
    end

    attribute :payload, :string do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :global_reference, [:reference], all_tenants?: true
  end
end

defmodule Chimwemwe.Platform.BanditSecurityTest.BodyProbe do
  @moduledoc false

  def init(owner), do: owner

  def call(conn, owner) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        send(owner, {:body_accepted, body})
        Plug.Conn.send_resp(conn, 200, body)

      {:more, _body, conn} ->
        Plug.Conn.send_resp(conn, 413, "bounded probe body")
    end
  end
end

defmodule Chimwemwe.Platform.DependencySecurityTest.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource Chimwemwe.Platform.DependencySecurityTest.Probe
  end
end
