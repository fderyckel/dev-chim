defmodule Chimwemwe.LocalBridge.OpenApi do
  @moduledoc """
  Checked OpenAPI contract for the local UI-1A read-only bridge.
  """

  @spec document() :: map()
  def document do
    %{
      "components" => %{
        "schemas" => %{
          "AssignmentOption" => %{
            "additionalProperties" => false,
            "properties" => %{
              "id" => %{"format" => "uuid", "type" => "string"},
              "label" => %{"maxLength" => 120, "minLength" => 1, "type" => "string"}
            },
            "required" => ["id", "label"],
            "type" => "object"
          },
          "AssignmentOptionsData" => %{
            "additionalProperties" => false,
            "properties" => %{
              "connection" => %{"const" => "local_core", "type" => "string"},
              "contract_version" => %{"const" => 1, "type" => "integer"},
              "memberships" => %{
                "items" => %{"$ref" => "#/components/schemas/AssignmentOption"},
                "type" => "array"
              },
              "roles" => %{
                "items" => %{"$ref" => "#/components/schemas/AssignmentOption"},
                "type" => "array"
              }
            },
            "required" => ["connection", "contract_version", "memberships", "roles"],
            "type" => "object"
          },
          "AssignmentOptionsResponse" => %{
            "additionalProperties" => false,
            "properties" => %{
              "data" => %{"$ref" => "#/components/schemas/AssignmentOptionsData"}
            },
            "required" => ["data"],
            "type" => "object"
          },
          "ErrorItem" => %{
            "additionalProperties" => false,
            "properties" => %{
              "code" => %{"type" => "string"},
              "detail" => %{"type" => "string"}
            },
            "required" => ["code", "detail"],
            "type" => "object"
          },
          "ErrorResponse" => %{
            "additionalProperties" => false,
            "properties" => %{
              "errors" => %{
                "items" => %{"$ref" => "#/components/schemas/ErrorItem"},
                "minItems" => 1,
                "type" => "array"
              }
            },
            "required" => ["errors"],
            "type" => "object"
          }
        },
        "securitySchemes" => %{
          "localSession" => %{"scheme" => "bearer", "type" => "http"}
        }
      },
      "info" => %{
        "description" => "Local-only read contract for UI-1A qualification.",
        "title" => "Chimwemwe UI-1A local bridge",
        "version" => "1.0.0"
      },
      "openapi" => "3.1.0",
      "paths" => %{
        "/api/v1/authority/assignment-options" => %{
          "get" => %{
            "operationId" => "getAssignmentOptions",
            "responses" => %{
              "200" => response("Assignment options", "AssignmentOptionsResponse"),
              "401" => response("Local session is missing or invalid", "ErrorResponse"),
              "403" => response("The session is not authorized", "ErrorResponse"),
              "500" => response("Internal failure", "ErrorResponse"),
              "503" => response("Required local dependency is unavailable", "ErrorResponse")
            },
            "security" => [%{"localSession" => []}],
            "summary" => "Read tenant-qualified role-assignment options"
          }
        }
      },
      "servers" => [%{"url" => "http://127.0.0.1:4001"}]
    }
  end

  @spec spec_path() :: String.t()
  def spec_path do
    Application.app_dir(:chimwemwe_core, "priv/openapi/ui1-local-v1.json")
  end

  defp response(description, schema) do
    %{
      "content" => %{
        "application/json" => %{
          "schema" => %{"$ref" => "#/components/schemas/#{schema}"}
        }
      },
      "description" => description,
      "headers" => %{
        "Cache-Control" => %{"schema" => %{"const" => "no-store", "type" => "string"}},
        "X-API-Version" => %{"schema" => %{"const" => "v1", "type" => "string"}}
      }
    }
  end
end
