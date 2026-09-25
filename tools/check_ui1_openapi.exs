alias Chimwemwe.LocalBridge.OpenApi

path = OpenApi.spec_path()
checked_document = path |> File.read!() |> Jason.decode!()

if checked_document != OpenApi.document() do
  raise "UI-1A OpenAPI contract drift detected: #{path}"
end

IO.puts("UI-1A OpenAPI contract matches the checked artifact.")
