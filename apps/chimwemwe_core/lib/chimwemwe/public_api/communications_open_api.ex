defmodule Chimwemwe.PublicApi.CommunicationsOpenApi do
  @moduledoc "Closed local synthetic COMM-1 named-action contract."
  @commands %{
    "create-draft" => ["title", "body", "receipt_required"],
    "revise-draft" => ["notice_id", "expected_version", "title", "body", "receipt_required"],
    "prepare-operation" => [
      "notice_id",
      "expected_version",
      "operation",
      "title",
      "body",
      "reason"
    ],
    "submit-for-approval" => ["notice_id", "expected_version", "preparation_id"],
    "approve-operation" => ["notice_id", "expected_version", "preparation_id"],
    "open-notice" => ["notice_id", "revision_id"],
    "confirm-receipt" => ["notice_id", "revision_id"],
    "command-outcome" => ["notice_id", "action", "idempotency_key"]
  }
  def spec_path, do: Application.app_dir(:chimwemwe_core, "priv/openapi/communications-v1.json")

  def document,
    do: %{
      "openapi" => "3.1.0",
      "info" => %{"title" => "Local synthetic staff notices", "version" => "1.0.0"},
      "components" => %{"schemas" => schemas()},
      "paths" => paths()
    }

  defp schemas do
    counts =
      object(
        Map.new(
          ["audience", "eligible", "no_eligible_account", "no_current_access"],
          &{&1, %{"type" => "integer", "minimum" => 0, "maximum" => 25}}
        )
      )

    receipt =
      object(%{
        "receipt_id" => uuid(),
        "revision_id" => uuid(),
        "statement" => text(),
        "recorded_at" => text(),
        "status" => text()
      })

    fields =
      Map.merge(
        Map.new(["notice_id", "revision_id", "preparation_id", "fact_id"], &{&1, uuid()}),
        %{
          "version" => %{"type" => "integer"},
          "number" => %{"type" => "integer"},
          "state" => %{
            "type" => "string",
            "enum" => ["draft", "pending", "published", "withdrawn"]
          },
          "institution" => text(),
          "classification" => text(),
          "title" => text(),
          "body" => text(),
          "reason" => text(),
          "receipt_required" => %{"type" => "boolean"},
          "eligibility" => counts,
          "expires_at" => text(),
          "operation" => %{"type" => "string", "enum" => ["publish", "correct", "withdraw"]},
          "statement" => text(),
          "recorded_at" => text(),
          "published_at" => text(),
          "metrics_as_of" => text(),
          "kind" => %{"type" => "string", "enum" => ["opening", "receipt"]},
          "status" => text(),
          "own_receipt" => %{"anyOf" => [receipt, %{"type" => "null"}]},
          "collection_notice" => text(),
          "opened" => %{"type" => "integer"},
          "receipt_confirmed" => %{"type" => "integer"}
        }
      )

    view = Map.put(object(fields), "required", ["notice_id"])

    result =
      Map.put(
        object(
          Map.take(fields, [
            "notice_id",
            "revision_id",
            "preparation_id",
            "fact_id",
            "version",
            "number",
            "state",
            "expires_at",
            "eligibility",
            "recorded_at",
            "kind"
          ])
        ),
        "required",
        ["notice_id"]
      )

    outcome =
      object(
        %{
          "status" => %{"type" => "string", "enum" => ["committed", "not_recorded"]},
          "result" => result
        },
        ["status"]
      )

    commands =
      Map.new(@commands, fn {name, keys} ->
        keys =
          if name == "command-outcome",
            do: keys,
            else: keys ++ ["idempotency_key", "causation_id"]

        fields = Map.new(keys, &{&1, input_property(&1)})

        fields =
          if name == "command-outcome",
            do: Map.put(fields, "notice_id", %{"anyOf" => [uuid(), %{"type" => "null"}]}),
            else: fields

        {name, object(fields)}
      end)

    Map.merge(commands, %{
      "NoticeView" => view,
      "WorkspaceResponse" =>
        object(%{"data" => object(%{"institution" => text(), "classification" => text()})}),
      "CommandOutcome" => outcome,
      "NoticeResponse" => object(%{"data" => %{"$ref" => "#/components/schemas/NoticeView"}}),
      "OutcomeResponse" =>
        object(%{"data" => %{"$ref" => "#/components/schemas/CommandOutcome"}}),
      "Error" =>
        object(%{
          "errors" => %{
            "type" => "array",
            "items" => object(%{"code" => text(), "message" => text()})
          }
        })
    })
  end

  defp paths do
    commands =
      Map.new(@commands, fn {name, _keys} ->
        response = if name == "command-outcome", do: "OutcomeResponse", else: "NoticeResponse"

        op =
          operation(name, response)
          |> Map.put("requestBody", %{
            "required" => true,
            "content" => %{
              "application/json" => %{"schema" => %{"$ref" => "#/components/schemas/" <> name}}
            }
          })

        {"/api/v1/communications/" <> name, %{"post" => op}}
      end)

    reads =
      Map.new(["draft", "review", "status", "metrics", "receipt"], fn name ->
        keys =
          if name in ["metrics", "receipt"], do: ["notice_id", "revision_id"], else: ["notice_id"]

        op =
          operation(name, "NoticeResponse")
          |> Map.put(
            "parameters",
            Enum.map(keys, fn key ->
              %{"name" => key, "in" => "query", "required" => true, "schema" => uuid()}
            end)
          )

        {"/api/v1/communications/" <> name, %{"get" => op}}
      end)

    Map.merge(commands, reads)
    |> Map.put("/api/v1/communications/workspace", %{
      "get" => operation("workspace", "WorkspaceResponse")
    })
  end

  defp operation(name, response),
    do: %{
      "operationId" => "communications_" <> String.replace(name, "-", "_"),
      "description" =>
        "Disabled by default; loopback synthetic only. No-store. Current session and authority required; unsafe methods require same-origin session-bound CSRF.",
      "responses" =>
        Map.new(["200", "400", "401", "403", "404", "409", "429", "503"], fn status ->
          ref = if status == "200", do: response, else: "Error"

          {status,
           %{
             "description" =>
               if(status == "200", do: "Authoritative result", else: "Non-disclosing failure"),
             "content" => %{
               "application/json" => %{"schema" => %{"$ref" => "#/components/schemas/" <> ref}}
             }
           }}
        end)
    }

  defp input_property(key)
       when key in [
              "notice_id",
              "revision_id",
              "preparation_id",
              "idempotency_key",
              "causation_id"
            ],
       do: uuid()

  defp input_property("expected_version"), do: %{"type" => "integer", "minimum" => 1}
  defp input_property("receipt_required"), do: %{"type" => "boolean", "default" => false}

  defp input_property("operation"),
    do: %{"type" => "string", "enum" => ["publish", "correct", "withdraw"]}

  defp input_property("title"), do: %{"type" => "string", "minLength" => 1, "maxLength" => 120}
  defp input_property("body"), do: %{"type" => "string", "minLength" => 1, "maxLength" => 2000}
  defp input_property("reason"), do: %{"type" => "string", "maxLength" => 240}

  defp input_property("action"),
    do: %{
      "type" => "string",
      "enum" => [
        "create_draft",
        "revise_draft",
        "prepare_operation",
        "submit_for_approval",
        "approve_operation",
        "open_notice",
        "confirm_receipt"
      ]
    }

  defp uuid, do: %{"type" => "string", "format" => "uuid"}
  defp text, do: %{"type" => "string"}

  defp object(fields, required \\ nil),
    do: %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => fields,
      "required" => required || Map.keys(fields)
    }
end
