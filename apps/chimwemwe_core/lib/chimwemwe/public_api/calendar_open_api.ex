defmodule Chimwemwe.PublicApi.CalendarOpenApi do
  @moduledoc false

  def schemas do
    uuid = %{"type" => "string", "format" => "uuid"}
    date = %{"type" => "string", "format" => "date"}
    digest = %{"type" => "string", "pattern" => "^[0-9a-f]{64}$"}
    key = %{"type" => "string", "pattern" => "^[a-z][a-z0-9_]{0,79}$"}

    period =
      object(%{
        "end_on" => date,
        "id" => uuid,
        "label" => bounded_string(),
        "period_type_key" => key,
        "sequence" => %{"type" => "integer", "minimum" => 1},
        "start_on" => date
      })

    closure =
      object(%{
        "date" => date,
        "id" => uuid,
        "label" => bounded_string(),
        "reason_key" => key
      })

    definition =
      object(%{
        "closures" => array(closure, 366),
        "code" => key,
        "end_on" => date,
        "instructional_weekdays" => %{
          "type" => "array",
          "items" => %{"type" => "integer", "minimum" => 1, "maximum" => 7},
          "minItems" => 1,
          "maxItems" => 7,
          "uniqueItems" => true
        },
        "label" => bounded_string(),
        "periods" => Map.put(array(period, 64), "minItems", 1),
        "start_on" => date,
        "time_zone" => bounded_string()
      })

    %{
      "CalendarPreparationView" =>
        object(%{
          "candidate_revision" => digest,
          "definition" => definition,
          "instructional_date_count" => %{"type" => "integer", "minimum" => 0},
          "lock_version" => %{"type" => "integer", "minimum" => 1},
          "status" => %{"type" => "string", "enum" => ["draft", "published"]}
        }),
      "CalendarPreparationResponse" => object(%{"data" => ref("CalendarPreparationView")}),
      "SaveCalendarDraftRequest" =>
        definition
        |> Map.fetch!("properties")
        |> Map.merge(%{
          "causation_id" => uuid,
          "expected_version" => %{"type" => "integer", "minimum" => 1},
          "idempotency_key" => uuid
        })
        |> object(),
      "PublishAcademicYearRequest" =>
        object(%{
          "causation_id" => uuid,
          "expected_version" => %{"type" => "integer", "minimum" => 1},
          "idempotency_key" => uuid
        }),
      "ResolveCalendarDateRequest" => object(%{"local_date" => date}),
      "CalendarResolution" =>
        object(%{
          "academic_period_id" => nullable(uuid),
          "candidate_revision" => digest,
          "closure_id" => nullable(uuid),
          "closure_reason_key" => nullable(key),
          "local_date" => date,
          "reason" => %{
            "type" => "string",
            "enum" => [
              "closure",
              "instructional_weekday",
              "ordinary_weekday_off",
              "outside_period"
            ]
          },
          "status" => %{"type" => "string", "enum" => ["instructional", "non_instructional"]}
        }),
      "CalendarResolutionResponse" => object(%{"data" => ref("CalendarResolution")})
    }
  end

  def paths do
    %{
      "/api/v1/calendar/preparation" => %{
        "get" => operation("getCalendarPreparation", nil, "CalendarPreparationResponse")
      },
      "/api/v1/calendar/save-draft" => %{
        "post" =>
          operation(
            "saveCalendarDraft",
            "SaveCalendarDraftRequest",
            "CalendarPreparationResponse"
          )
      },
      "/api/v1/calendar/publish" => %{
        "post" =>
          operation(
            "publishAcademicYear",
            "PublishAcademicYearRequest",
            "CalendarPreparationResponse"
          )
      },
      "/api/v1/calendar/resolve" => %{
        "post" =>
          operation(
            "resolveCalendarDate",
            "ResolveCalendarDateRequest",
            "CalendarResolutionResponse"
          )
      }
    }
  end

  defp operation(id, input, output) do
    common = %{
      "operationId" => id,
      "security" => [%{"applicationSession" => []}],
      "description" =>
        "Disabled by default. Local synthetic HTTPS qualification for one server-selected calendar only. Calendar, academic-year, institution, tenant, actor, placement and capability authority are never accepted from browser input. POST requires exact Origin and X-CSRF-Token. No automatic retry.",
      "responses" =>
        Map.new([200, 400, 401, 403, 404, 409, 503], fn status ->
          {Integer.to_string(status),
           %{
             "description" =>
               if(status == 200, do: "Current writer result", else: "Non-disclosing failure"),
             "content" => %{
               "application/json" => %{
                 "schema" => ref(if(status == 200, do: output, else: "ErrorResponse"))
               }
             }
           }}
        end)
    }

    if input do
      Map.merge(common, %{
        "parameters" =>
          Enum.map(["Origin", "X-CSRF-Token"], fn name ->
            %{
              "in" => "header",
              "name" => name,
              "required" => true,
              "schema" => %{"type" => "string"}
            }
          end),
        "requestBody" => %{
          "required" => true,
          "content" => %{"application/json" => %{"schema" => ref(input)}}
        }
      })
    else
      common
    end
  end

  defp ref(name), do: %{"$ref" => "#/components/schemas/" <> name}
  defp nullable(schema), do: %{"anyOf" => [schema, %{"type" => "null"}]}
  defp bounded_string, do: %{"type" => "string", "minLength" => 1, "maxLength" => 240}

  defp object(properties),
    do: %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => properties,
      "required" => Map.keys(properties) |> Enum.sort()
    }

  defp array(items, max), do: %{"type" => "array", "items" => items, "maxItems" => max}
end
