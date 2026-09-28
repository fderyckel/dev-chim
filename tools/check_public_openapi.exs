alias Chimwemwe.PublicApi.OpenApi

path = OpenApi.spec_path()
document = OpenApi.document()

if "--write" in System.argv() do
  File.mkdir_p!(Path.dirname(path))
  File.write!(path, Jason.encode_to_iodata!(document, pretty: true))
end

checked_document = path |> File.read!() |> Jason.decode!()

if checked_document != document do
  raise "Public session OpenAPI contract drift detected: #{path}"
end

IO.puts("Public session OpenAPI contract matches the checked artifact.")
