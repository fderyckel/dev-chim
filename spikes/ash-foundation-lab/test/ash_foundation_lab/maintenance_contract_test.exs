defmodule AshFoundationLab.MaintenanceContractTest do
  use ExUnit.Case, async: true

  @spike_root Path.expand("../..", __DIR__)
  @manifest_path Path.join(@spike_root, "priv/maintenance/owned-boundaries.json")
  @required_boundary_fields ~w(
    id
    classification
    owner
    cost
    bounded_remedy
    closure_gate
    recheck_trigger
    sources
    evidence
  )
  @unresolved_markers ~w(TARGET_REQUIRED OWNER_REQUIRED DATE_REQUIRED EVIDENCE_REQUIRED NOT_RUN TBD)

  test "owned boundary manifest is complete, bounded, and linked to existing evidence" do
    manifest = manifest()

    assert manifest["schema_version"] == 1
    assert manifest["status"] == "phase0_evidence"
    assert non_blank?(manifest["owner"])
    assert manifest["reviewed_on"] == "2026-09-15"
    assert length(manifest["boundaries"]) == 8

    ids = Enum.map(manifest["boundaries"], & &1["id"])
    assert Enum.uniq(ids) == ids

    for boundary <- manifest["boundaries"] do
      assert Map.keys(boundary) |> Enum.sort() == Enum.sort(@required_boundary_fields)

      for field <- @required_boundary_fields -- ["sources"] do
        value = Map.fetch!(boundary, field)
        assert non_blank?(value), "#{boundary["id"]}.#{field} must be non-blank"

        refute Enum.any?(@unresolved_markers, &String.contains?(value, &1)),
               "#{boundary["id"]}.#{field} contains an unresolved marker"
      end

      sources = Map.fetch!(boundary, "sources")
      assert sources != []
      assert Enum.uniq(sources) == sources

      for source <- sources do
        assert_regular_file_inside_spike!(source)
      end

      boundary["evidence"]
      |> String.split("#", parts: 2)
      |> hd()
      |> assert_regular_file_inside_spike!()
    end
  end

  test "every current non-atomic or raw-SQL source is explicitly owned" do
    boundaries = boundaries_by_id()

    assert source_files_containing("require_atomic? false") ==
             boundaries
             |> Map.fetch!("transaction_backed_non_atomic_action")
             |> Map.fetch!("sources")

    assert source_files_matching(~r/\bRepo\.query!?\(/) ==
             boundaries
             |> Map.fetch!("dynamic_repository_sql")
             |> Map.fetch!("sources")
  end

  test "edge adapters and retained-data choreography remain explicit" do
    boundaries = boundaries_by_id()
    api_router = source!("lib/ash_foundation_lab/api_router.ex")
    json_api_router = source!("lib/ash_foundation_lab/json_api_router.ex")

    assert api_router =~ "plug(AshFoundationLab.JsonApiPageLimit)"
    assert api_router =~ "plug(AshFoundationLab.JsonApiFailureHeaders)"

    assert json_api_router =~
             "modify_open_api: {AshFoundationLab.JsonApiContract, :modify_open_api, []}"

    expected_migration_sources =
      @spike_root
      |> Path.join("priv/retained_data_migration_rehearsal/migrations/*.exs")
      |> Path.wildcard()
      |> Enum.map(&Path.relative_to(&1, @spike_root))
      |> Enum.sort()

    registered_migration_sources =
      boundaries
      |> Map.fetch!("retained_data_migration_choreography")
      |> Map.fetch!("sources")
      |> Enum.filter(&String.ends_with?(&1, ".exs"))
      |> Enum.sort()

    assert registered_migration_sources == expected_migration_sources
  end

  test "maintained source has no authorization bypass or silently skipped test" do
    for path <- lib_source_paths() do
      refute File.read!(path) =~ ~r/authorize\?:\s*false/,
             "authorization bypass found in #{Path.relative_to(path, @spike_root)}"
    end

    skip_markers = ["@tag" <> " :skip", "@tag" <> " skip:", "@moduletag" <> " :skip"]

    test_paths = Path.wildcard(Path.join(@spike_root, "test/**/*_test.exs"))

    for path <- test_paths, marker <- skip_markers do
      refute File.read!(path) =~ marker,
             "silent skip marker found in #{Path.relative_to(path, @spike_root)}"
    end

    refute source!("test/test_helper.exs") =~ "exclude" <> ":"
  end

  test "invalid Ash DSL input fails with actionable compile feedback" do
    error =
      assert_raise RuntimeError, fn ->
        Code.compile_string("""
        defmodule AshFoundationLab.InvalidMaintenanceProbe do
          use Ash.Resource, domain: nil

          attributes do
            attribute :name, :phase0_unknown_type
          end
        end
        """)
      end

    message = Exception.message(error)
    assert message =~ ":phase0_unknown_type is not a valid type"
    assert message =~ "Valid types include"
    assert message =~ ":string -> Ash.Type.String"
  end

  defp manifest do
    @manifest_path
    |> File.read!()
    |> Jason.decode!()
  end

  defp boundaries_by_id do
    Map.new(manifest()["boundaries"], &{&1["id"], &1})
  end

  defp source_files_containing(fragment) do
    source_files_matching(Regex.compile!(Regex.escape(fragment)))
  end

  defp source_files_matching(pattern) do
    lib_source_paths()
    |> Enum.filter(&(File.read!(&1) =~ pattern))
    |> Enum.map(&Path.relative_to(&1, @spike_root))
    |> Enum.sort()
  end

  defp lib_source_paths do
    Path.wildcard(Path.join(@spike_root, "lib/**/*.ex"))
  end

  defp source!(relative_path) do
    @spike_root
    |> Path.join(relative_path)
    |> File.read!()
  end

  defp assert_regular_file_inside_spike!(relative_path) do
    expanded = Path.expand(relative_path, @spike_root)
    repository_root = Path.expand("../..", @spike_root)

    assert expanded == repository_root or String.starts_with?(expanded, repository_root <> "/")
    assert File.regular?(expanded), "missing maintained artifact #{relative_path}"
  end

  defp non_blank?(value), do: is_binary(value) and String.trim(value) != ""
end
