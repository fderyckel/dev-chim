alias Chimwemwe.PublicApi.StaffOpenApi
path = StaffOpenApi.spec_path()
document = StaffOpenApi.document()

if "--write" in System.argv() do
  File.mkdir_p!(Path.dirname(path))
  File.write!(path, Jason.encode_to_iodata!(document, pretty: true))
end

if Jason.decode!(File.read!(path)) != document do
  raise "Staff account OpenAPI contract drift detected"
end

IO.puts("Staff account OpenAPI contract matches the checked artifact.")
