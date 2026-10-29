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

    prepared_class =
      object(%{
        "id" => uuid,
        "code" => %{"type" => "string", "pattern" => "^[a-z][a-z0-9_]{0,79}$"},
        "label" => %{"type" => "string", "minLength" => 1, "maxLength" => 160}
      })

    prepared_student =
      object(%{
        "id" => uuid,
        "name" => %{"type" => "string", "minLength" => 1, "maxLength" => 200}
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
          "submission_id" => %{"anyOf" => [uuid, %{"type" => "null"}]},
          "revision_id" => %{"anyOf" => [uuid, %{"type" => "null"}]},
          "correction_number" => %{"type" => "integer", "minimum" => 0, "maximum" => 10},
          "correction_reason" => %{
            "anyOf" => [
              %{"type" => "string", "enum" => ["marking_error"]},
              %{"type" => "null"}
            ]
          }
        }),
      "AttendanceResponse" => object(%{"data" => ref("AttendanceView")}),
      "ClassroomPreparationView" =>
        object(%{
          "institution_name" => %{"type" => "string"},
          "academic_year_label" => %{"type" => "string"},
          "educator_name" => %{"type" => "string"},
          "class" => %{"anyOf" => [prepared_class, %{"type" => "null"}]},
          "students" => array(prepared_student, 60)
        }),
      "ClassroomPreparationResponse" => object(%{"data" => ref("ClassroomPreparationView")}),
      "PrepareClassRequest" =>
        object(%{
          "code" => %{"type" => "string", "pattern" => "^[a-z][a-z0-9_]{0,79}$"},
          "label" => %{"type" => "string", "minLength" => 1, "maxLength" => 160},
          "idempotency_key" => uuid,
          "causation_id" => uuid
        }),
      "AddStudentRequest" =>
        object(%{
          "display_name" => %{"type" => "string", "minLength" => 1, "maxLength" => 200},
          "idempotency_key" => uuid,
          "causation_id" => uuid
        }),
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
      "CorrectAttendanceRequest" =>
        object(%{
          "class_id" => uuid,
          "submission_id" => uuid,
          "expected_revision_id" => uuid,
          "reason_code" => %{"type" => "string", "enum" => ["marking_error"]},
          "idempotency_key" => uuid,
          "causation_id" => uuid,
          "marks" =>
            Map.put(array(object(%{"person_id" => uuid, "mark" => mark}), 60), "minItems", 1)
        }),
      "AttendanceReceiptResponse" => object(%{"data" => object(%{"submission_id" => uuid})}),
      "AttendanceCorrectionReceiptResponse" =>
        object(%{
          "data" =>
            object(%{
              "submission_id" => uuid,
              "correction_id" => uuid,
              "correction_number" => %{"type" => "integer", "minimum" => 1, "maximum" => 10}
            })
        })
    }
  end

  def paths do
    %{
      "/api/v1/classroom/classes" => %{
        "get" => operation("assignedClasses", nil, "AssignedClassesResponse")
      },
      "/api/v1/classroom/preparation" => %{
        "get" =>
          operation(
            "classroomPreparation",
            nil,
            "ClassroomPreparationResponse",
            "Read one server-owned local synthetic preparation workspace. No directory, selector, search or pagination."
          )
      },
      "/api/v1/classroom/prepare-class" => %{
        "post" =>
          operation(
            "prepareClass",
            "PrepareClassRequest",
            "ClassroomPreparationResponse",
            "Create the workspace's one class and educator assignment atomically. Scope is server-owned. POST requires exact Origin and X-CSRF-Token; do not retry with a new idempotency key."
          )
      },
      "/api/v1/classroom/add-student" => %{
        "post" =>
          operation(
            "addStudentToPreparedClass",
            "AddStudentRequest",
            "ClassroomPreparationResponse",
            "Register one fictional student, participation, enrolment and placement atomically. Maximum 60 students. POST requires exact Origin and X-CSRF-Token; do not retry with a new idempotency key."
          )
      },
      "/api/v1/classroom/prepare-attendance" => %{
        "post" => operation("prepareAttendance", "PrepareAttendanceRequest", "AttendanceResponse")
      },
      "/api/v1/classroom/submit-attendance" => %{
        "post" =>
          operation("submitAttendance", "SubmitAttendanceRequest", "AttendanceReceiptResponse")
      },
      "/api/v1/classroom/correct-attendance" => %{
        "post" =>
          operation(
            "correctAttendance",
            "CorrectAttendanceRequest",
            "AttendanceCorrectionReceiptResponse",
            "Correct today's saved register through one complete append-only successor. Requires the exact current revision and marking_error reason. No backdating, free text or automatic retry."
          )
      }
    }
  end

  defp operation(id, input, output, description \\ nil) do
    common = %{
      "operationId" => id,
      "security" => [%{"applicationSession" => []}],
      "description" =>
        description ||
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
