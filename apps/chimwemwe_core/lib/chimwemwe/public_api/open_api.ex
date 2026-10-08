defmodule Chimwemwe.PublicApi.OpenApi do
  @moduledoc "Checked OpenAPI contract for the public application-session adapter."

  alias Chimwemwe.PublicApi.{CalendarOpenApi, ClassroomOpenApi}

  @spec document() :: map()
  def document do
    %{
      "components" => %{
        "schemas" =>
          schemas()
          |> Map.merge(ClassroomOpenApi.schemas())
          |> Map.merge(CalendarOpenApi.schemas()),
        "securitySchemes" => %{
          "applicationSession" => %{
            "in" => "cookie",
            "name" => "__Host-chimwemwe-session",
            "type" => "apiKey"
          }
        }
      },
      "info" => %{
        "description" =>
          "Provider-neutral, same-origin application-session contract. Provider callbacks are not a client API.",
        "title" => "Chimwemwe public session API",
        "version" => "1.0.0"
      },
      "openapi" => "3.1.0",
      "paths" =>
        paths()
        |> Map.merge(ClassroomOpenApi.paths())
        |> Map.merge(CalendarOpenApi.paths())
    }
  end

  @spec spec_path() :: String.t()
  def spec_path do
    Application.app_dir(:chimwemwe_core, "priv/openapi/public-session-v1.json")
  end

  defp schemas do
    %{
      "ElevateSupportRequest" =>
        object(
          %{"grant_id" => %{"format" => "uuid", "type" => "string"}},
          ["grant_id"]
        ),
      "ErrorItem" =>
        object(
          %{
            "code" => %{"type" => "string"},
            "detail" => %{"type" => "string"}
          },
          ["code", "detail"]
        ),
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
      },
      "SessionData" =>
        object(
          %{
            "actor_id" => %{"format" => "uuid", "type" => "string"},
            "assurance" => %{"maxLength" => 120, "minLength" => 1, "type" => "string"},
            "csrf_token" => %{
              "description" => "Same-origin proof required by unsafe session actions.",
              "maxLength" => 200,
              "minLength" => 20,
              "type" => "string"
            },
            "idle_expires_at" => %{"format" => "date-time", "type" => "string"},
            "support" => %{
              "anyOf" => [
                %{"$ref" => "#/components/schemas/SupportSession"},
                %{"type" => "null"}
              ]
            }
          },
          ["actor_id", "assurance", "csrf_token", "idle_expires_at", "support"]
        ),
      "SessionResponse" =>
        object(%{"data" => %{"$ref" => "#/components/schemas/SessionData"}}, ["data"]),
      "SupportSession" =>
        object(
          %{
            "mode" => %{"const" => "support", "type" => "string"},
            "support_actor_id" => %{"format" => "uuid", "type" => "string"},
            "purpose" => %{"maxLength" => 240, "minLength" => 3, "type" => "string"},
            "expires_at" => %{"format" => "date-time", "type" => "string"},
            "capability_scope" => %{
              "items" => %{"maxLength" => 120, "minLength" => 3, "type" => "string"},
              "maxItems" => 8,
              "minItems" => 1,
              "type" => "array"
            }
          },
          ["mode", "support_actor_id", "purpose", "expires_at", "capability_scope"]
        ),
      "SupportSessionResponse" =>
        object(%{"data" => %{"$ref" => "#/components/schemas/SupportSession"}}, ["data"])
    }
  end

  defp paths do
    %{
      "/api/v1/session" => %{
        "get" => %{
          "operationId" => "getCurrentSession",
          "responses" => %{
            "200" => response("Current application session", "SessionResponse"),
            "401" => response("Session missing, expired, revoked, or stale", "ErrorResponse")
          },
          "security" => [%{"applicationSession" => []}],
          "summary" => "Read the current writer-validated application session"
        }
      },
      "/api/v1/session/logout" => %{
        "post" => %{
          "description" => "Requires exact Origin and X-CSRF-Token headers.",
          "operationId" => "logoutCurrentSession",
          "responses" => %{
            "204" => %{"description" => "Authoritative session invalidated"},
            "401" => response("Session missing or no longer current", "ErrorResponse"),
            "403" => response("Origin or CSRF proof rejected", "ErrorResponse"),
            "503" => response("Writer temporarily unavailable", "ErrorResponse")
          },
          "security" => [%{"applicationSession" => []}],
          "summary" => "Log out the current exact session"
        }
      },
      "/api/v1/session/support/elevate" => %{
        "post" => %{
          "description" => "Requires exact Origin and X-CSRF-Token headers.",
          "operationId" => "elevateSupportSession",
          "requestBody" => %{
            "content" => %{
              "application/json" => %{
                "schema" => %{"$ref" => "#/components/schemas/ElevateSupportRequest"}
              }
            },
            "required" => true
          },
          "responses" => %{
            "200" => response("Visible bounded support mode", "SupportSessionResponse"),
            "400" => response("Invalid exact grant reference", "ErrorResponse"),
            "401" => response("Session missing or no longer current", "ErrorResponse"),
            "403" => response("Grant, origin, or CSRF proof rejected", "ErrorResponse"),
            "503" => response("Writer temporarily unavailable", "ErrorResponse")
          },
          "security" => [%{"applicationSession" => []}],
          "summary" => "Activate one pre-approved support grant"
        }
      }
    }
  end

  defp object(properties, required) do
    %{
      "additionalProperties" => false,
      "properties" => properties,
      "required" => required,
      "type" => "object"
    }
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
