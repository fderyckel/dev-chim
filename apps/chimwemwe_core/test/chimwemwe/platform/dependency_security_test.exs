defmodule Chimwemwe.Platform.DependencySecurityTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Platform.DependencySecurityTest.Probe
  alias Chimwemwe.Repo
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.UUID

  setup do
    start_supervised!({Repo, []})
    :ok = Sandbox.checkout(Repo)

    # The sandbox keeps the temporary table and every Ash operation on one connection.
    Repo.query!("""
    CREATE TEMP TABLE dependency_security_probes (
      id uuid PRIMARY KEY,
      tenant_id uuid NOT NULL,
      reference text NOT NULL UNIQUE,
      payload text NOT NULL
    )
    """)

    %{tenant_a: UUID.generate(), tenant_b: UUID.generate()}
  end

  for identity <- [nil, :global_reference],
      mode <- [:single, :bulk],
      return_skipped? <- [false, true] do
    @identity identity
    @mode mode
    @return_skipped return_skipped?

    test "#{mode} #{@identity || :primary_key} upsert cannot return or modify another tenant, skipped=#{return_skipped?}",
         f do
      victim = seed!(f.tenant_a)

      input = %{
        id: if(@identity, do: UUID.generate(), else: victim.id),
        reference: victim.reference,
        payload: "fictional replacement"
      }

      result =
        store(@mode, input,
          tenant: f.tenant_b,
          upsert_identity: @identity,
          return_skipped_upsert?: @return_skipped
        )

      withheld? =
        case result do
          {:error, _} -> true
          {:ok, nil} -> true
          %Ash.BulkResult{records: records} -> records in [nil, []]
          _ -> false
        end

      assert withheld?

      assert Repo.query!("SELECT tenant_id::text, payload FROM dependency_security_probes").rows ==
               [[f.tenant_a, "fictional original"]]
    end
  end

  for identity <- [nil, :global_reference], mode <- [:single, :bulk] do
    @identity identity
    @mode mode

    test "#{mode} #{@identity || :primary_key} upsert preserves legitimate same-tenant writes",
         f do
      original = seed!(f.tenant_a)

      result =
        store(
          @mode,
          %{id: original.id, reference: original.reference, payload: "fictional amended"},
          tenant: f.tenant_a,
          upsert_identity: @identity
        )

      amended =
        case result do
          {:ok, record} -> record
          %Ash.BulkResult{status: :success, records: [record]} -> record
        end

      assert amended.id == original.id
      assert amended.tenant_id == f.tenant_a
      assert amended.payload == "fictional amended"
    end
  end

  defp seed!(tenant) do
    Ash.create!(Probe, %{reference: UUID.generate(), payload: "fictional original"},
      action: :store_probe,
      tenant: tenant
    )
  end

  defp store(:single, input, options),
    do: Ash.create(Probe, input, Keyword.put(options, :action, :store_probe))

  defp store(:bulk, input, options) do
    Ash.bulk_create(
      [input],
      Probe,
      :store_probe,
      Keyword.merge(options,
        upsert_fields: [:payload],
        return_records?: true,
        return_errors?: true,
        max_concurrency: 0
      )
    )
  end
end

defmodule Chimwemwe.Platform.BanditSecurityTest do
  use ExUnit.Case, async: false

  alias __MODULE__.BodyProbe

  test "uses the patched release for fragmented HTTP/2 request bodies" do
    assert Version.compare(to_string(Application.spec(:bandit, :vsn)), "1.14.1") in [:eq, :gt]
  end

  setup do
    listener =
      start_supervised!(
        {Bandit,
         plug: {BodyProbe, self()},
         ip: {127, 0, 0, 1},
         port: 0,
         startup_log: false,
         http_options: [log_protocol_errors: false]}
      )

    {:ok, {_address, port}} = ThousandIsland.listener_info(listener)
    %{port: port}
  end

  test "rejects bare LF and CR in chunk extensions without accepting either request body", f do
    for extension <- [";x=\ny", ";x=\ry"] do
      response =
        exchange(
          f.port,
          request("Transfer-Encoding: chunked\r\n", "1" <> extension <> "\r\nx\r\n0\r\n\r\n")
        )

      assert response =~ "HTTP/1.1 400"
      refute_received {:body_accepted, _}
    end
  end

  test "bounds significant decimal digits in the shared header parser" do
    excessive = String.duplicate("9", 1_000)

    assert {:error, _} = Bandit.Headers.get_content_length([{"content-length", excessive}])

    assert_raise Bandit.HTTPError, fn ->
      Bandit.Headers.parse_hostlike_header!("localhost:" <> excessive)
    end
  end

  test "preserves ordinary content-length and quoted chunk-extension requests", f do
    for {headers, body} <- [
          {"Content-Length: 1\r\n", "x"},
          {"Content-Length: " <> String.duplicate("0", 1_000) <> "1\r\n", "x"},
          {"Transfer-Encoding: chunked\r\n", "1;x=\"y\"\r\nx\r\n0\r\n\r\n"}
        ] do
      response = exchange(f.port, request(headers, body))
      assert response =~ "HTTP/1.1 200"
      assert String.ends_with?(response, "x")
      assert_received {:body_accepted, "x"}
      refute_received {:body_accepted, _}
    end
  end

  defp request(headers, body),
    do: "POST / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n" <> headers <> "\r\n" <> body

  defp exchange(port, request) do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 2_000)

    try do
      :ok = :gen_tcp.send(socket, request)
      receive_response(socket, "")
    after
      :gen_tcp.close(socket)
    end
  end

  defp receive_response(socket, response) do
    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, bytes} -> receive_response(socket, response <> bytes)
      {:error, :closed} -> response
      {:error, reason} -> flunk("bounded local HTTP probe failed: #{inspect(reason)}")
    end
  end
end

defmodule Chimwemwe.Platform.JoseSecurityTest do
  use ExUnit.Case, async: true

  test "ECDSA accepts the signed control and rejects noncanonical signature padding" do
    key = JOSE.JWK.generate_key({:ec, "P-256"})

    {_metadata, signed} =
      key
      |> JOSE.JWS.sign("fictional dependency probe", %{"alg" => "ES256"})
      |> JOSE.JWS.compact()

    public_key = JOSE.JWK.to_public(key)
    assert {true, "fictional dependency probe", _} = JOSE.JWS.verify(public_key, signed)
    [header, payload, encoded_signature] = String.split(signed, ".")

    <<left::binary-size(32), right::binary-size(32)>> =
      Base.url_decode64!(encoded_signature, padding: false)

    for padding_size <- [1, 3] do
      padding = :binary.copy(<<0>>, padding_size)
      signature = Base.url_encode64(padding <> left <> padding <> right, padding: false)
      altered = Enum.join([header, payload, signature], ".")
      assert {false, _, _} = JOSE.JWS.verify(public_key, altered)
    end
  end

  test "pure Erlang GCM accepts a complete tag and refuses truncated or oversized tags" do
    key = :crypto.strong_rand_bytes(16)
    iv = :crypto.strong_rand_bytes(12)
    plaintext = "fictional dependency probe"
    {ciphertext, tag} = :jose_jwa_aes.block_encrypt({:aes_gcm, 128}, key, iv, {"", plaintext})

    assert :jose_jwa_aes.block_decrypt({:aes_gcm, 128}, key, iv, {"", ciphertext, tag}) ==
             plaintext

    for invalid_tag <- ["", binary_part(tag, 0, 1), binary_part(tag, 0, 15), tag <> <<0>>] do
      result =
        try do
          :jose_jwa_aes.block_decrypt({:aes_gcm, 128}, key, iv, {"", ciphertext, invalid_tag})
        rescue
          FunctionClauseError -> :rejected
        end

      assert result in [:error, :rejected]
    end
  end
end
