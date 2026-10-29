alias Chimwemwe.PublicApi.CommunicationsOpenApi
path = CommunicationsOpenApi.spec_path()
document = CommunicationsOpenApi.document()

if "--write" in System.argv() do
  File.mkdir_p!(Path.dirname(path))
  File.write!(path, Jason.encode_to_iodata!(document, pretty: true))
end

if Jason.decode!(File.read!(path)) != document,
  do: raise("Communications OpenAPI contract drift detected")

IO.puts("Communications OpenAPI contract matches the checked artifact.")
