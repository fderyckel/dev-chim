defmodule Chimwemwe.PublicApi.ClassroomOpenApi do
  @moduledoc false
  def schemas do
    uuid = %{"type" => "string", "format" => "uuid"}
    date = %{"type" => "string", "format" => "date"}
    digest = %{"type" => "string", "pattern" => "^[0-9a-f]{64}$"}
    mark = %{"type" => "string", "enum" => ["present", "absent", "late"]}
    class = object(%{"id" => uuid, "label" => %{"type" => "string"}, "local_date" => date})

    student =
      object(%{
        "id" => uuid,
        "name" => %{"type" => "string"},
        "mark" => %{"anyOf" => [mark, %{"type" => "null"}]}
      })

    %{
      "AssignedClassesResponse" => object(%{"data" => array(class, 12)}),
      "PrepareAttendanceRequest" => object(%{"class_id" => uuid}),
      "AttendanceView" =>
        object(%{
          "class_id" => uuid,
          "label" => %{"type" => "string"},
          "local_date" => date,
          "calendar_revision" => digest,
          "roster_basis" => digest,
          "students" => array(student, 60),
          "submission_id" => %{"anyOf" => [uuid, %{"type" => "null"}]}
        }),
      "AttendanceResponse" => object(%{"data" => ref("AttendanceView")}),
      "SubmitAttendanceRequest" =>
        object(%{
          "class_id" => uuid,
          "local_date" => date,
          "calendar_revision" => digest,
          "roster_basis" => digest,
          "idempotency_key" => uuid,
          "causation_id" => uuid,
          "marks" =>
            Map.put(array(object(%{"person_id" => uuid, "mark" => mark}), 60), "minItems", 1)
        }),
      "AttendanceReceiptResponse" => object(%{"data" => object(%{"submission_id" => uuid})})
    }
  end

  def paths do
    %{
      "/api/v1/classroom/classes" => %{
        "get" => operation("assignedClasses", nil, "AssignedClassesResponse")
      },
      "/api/v1/classroom/prepare-attendance" => %{
        "post" => operation("prepareAttendance", "PrepareAttendanceRequest", "AttendanceResponse")
      },
      "/api/v1/classroom/submit-attendance" => %{
        "post" =>
          operation("submitAttendance", "SubmitAttendanceRequest", "AttendanceReceiptResponse")
      }
    }
  end

  defp operation(id, input, output) do
    common = %{
      "operationId" => id,
      "security" => [%{"applicationSession" => []}],
      "description" =>
        "Disabled by default. Local synthetic HTTPS qualification only. Today and assigned classes only; no arbitrary dates, search or pagination. Cumulative actor/day scope: 12 classes, 720 people. POST requires exact Origin and X-CSRF-Token. No automatic retry.",
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

  defp object(properties),
    do: %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => properties,
      "required" => Map.keys(properties) |> Enum.sort()
    }

  defp array(items, max), do: %{"type" => "array", "items" => items, "maxItems" => max}
end
