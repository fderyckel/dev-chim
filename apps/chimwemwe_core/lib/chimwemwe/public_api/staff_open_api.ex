defmodule Chimwemwe.PublicApi.StaffOpenApi do
  @moduledoc "Checked, guarded synthetic staff-account and local-login API."

  def document do
    %{
      "openapi" => "3.1.0",
      "info" => %{"title" => "Synthetic staff accounts", "version" => "1.0.0"},
      "components" => %{"schemas" => schemas()},
      "paths" => paths()
    }
  end

  def spec_path,
    do: Application.app_dir(:chimwemwe_core, "priv/openapi/staff-accounts-v1.json")

  defp schemas do
    text = %{"type" => "string"}
    boolean = %{"type" => "boolean"}
    uuid = %{"type" => "string", "format" => "uuid"}
    version = %{"type" => "integer", "minimum" => 1}
    locale = %{"type" => "string", "enum" => ["en", "fr", "en-MW"]}
    nullable_text = %{"anyOf" => [text, %{"type" => "null"}]}
    keys = %{"idempotency_key" => uuid, "causation_id" => uuid}
    target = Map.merge(keys, %{"id" => uuid, "expected_version" => version})

    details = %{
      "given_name" => nullable_text,
      "family_name" => nullable_text,
      "display_name" => text,
      "locale" => locale
    }

    profile = object(%{"id" => uuid, "label" => text})

    account =
      object(
        Map.merge(details, %{
          "id" => uuid,
          "account_id" => uuid,
          "association_id" => uuid,
          "actor_id" => uuid,
          "membership_id" => uuid,
          "email" => text,
          "enabled" => %{"type" => "boolean"},
          "lock_version" => version,
          "status" => text,
          "source_current" => %{"type" => "boolean"},
          "access_state" => %{
            "type" => "string",
            "enum" => [
              "source_unavailable",
              "suspended",
              "first_login_required",
              "credential_suspended",
              "enabled"
            ]
          },
          "roles" => array(ref("StaffAccessProfile")),
          "temporary_password_expires_at" => nullable_text
        })
      )

    receipt =
      object(%{
        "id" => uuid,
        "account_id" => uuid,
        "lock_version" => version,
        "audit_reference" => uuid,
        "event_id" => uuid,
        "temporary_password" => nullable_text,
        "temporary_password_expires_at" => nullable_text
      })

    %{
      "StaffAccount" => account,
      "StaffCandidate" =>
        object(%{
          "association_id" => uuid,
          "membership_id" => uuid,
          "display_name" => text,
          "reference" => text
        }),
      "StaffAccessProfile" => profile,
      "StaffAccountsResponse" =>
        response(
          object(%{
            "accounts" => array(ref("StaffAccount")),
            "eligible_staff" => array(ref("StaffCandidate")),
            "profiles" => array(ref("StaffAccessProfile")),
            "truncated" => %{"type" => "boolean"},
            "locale" => locale,
            "institution_label" => text
          })
        ),
      "StaffLoginResponse" =>
        response(
          object(%{
            "stage" => %{
              "type" => "string",
              "enum" => ["anonymous", "first_login", "authenticated"]
            },
            "csrf_token" => text,
            "locale" => locale,
            "next_path" => text
          })
        ),
      "StaffAccountActionResponse" => response(receipt),
      "StaffPreferencesResponse" =>
        response(
          object(
            Map.merge(details, %{
              "id" => uuid,
              "lock_version" => version,
              "navigation" => object(%{"accounts" => boolean, "classroom" => boolean})
            })
          )
        ),
      "StaffCancelLoginRequest" => object(%{"csrf_token" => text}),
      "StaffLoginRequest" =>
        object(%{"email" => text, "password" => text, "csrf_token" => text, "locale" => locale}),
      "StaffReplacePasswordRequest" =>
        object(%{"password" => text, "confirmation" => text, "csrf_token" => text}),
      "StaffProvisionRequest" =>
        object(Map.merge(Map.merge(keys, details), %{"association_id" => uuid, "email" => text})),
      "StaffReviseDetailsRequest" => object(Map.merge(target, details)),
      "StaffSetAccessRequest" => object(Map.put(target, "profile_id", uuid)),
      "StaffTargetRequest" => object(target),
      "StaffPreferencesRequest" =>
        object(Map.merge(keys, %{"locale" => locale, "expected_version" => version}))
    }
  end

  defp paths do
    %{
      "/api/v1/staff-login" => %{
        "get" => operation("staffLoginState", "StaffLoginResponse"),
        "post" => operation("staffLogin", "StaffLoginResponse", "StaffLoginRequest")
      },
      "/api/v1/staff-login/cancel" => %{
        "post" => operation("staffCancelLogin", "StaffLoginResponse", "StaffCancelLoginRequest")
      },
      "/api/v1/staff-login/replace-password" => %{
        "post" =>
          operation("staffReplacePassword", "StaffLoginResponse", "StaffReplacePasswordRequest")
      },
      "/api/v1/staff-accounts" => %{"get" => operation("staffAccounts", "StaffAccountsResponse")},
      "/api/v1/staff-accounts/provision" => %{
        "post" =>
          operation("staffProvision", "StaffAccountActionResponse", "StaffProvisionRequest")
      },
      "/api/v1/staff-accounts/revise-details" => %{
        "post" =>
          operation(
            "staffReviseDetails",
            "StaffAccountActionResponse",
            "StaffReviseDetailsRequest"
          )
      },
      "/api/v1/staff-accounts/set-access" => %{
        "post" =>
          operation("staffSetAccess", "StaffAccountActionResponse", "StaffSetAccessRequest")
      },
      "/api/v1/staff-accounts/revoke-access-profile" => %{
        "post" =>
          operation("staffRevokeAccess", "StaffAccountActionResponse", "StaffSetAccessRequest")
      },
      "/api/v1/staff-accounts/suspend-access" => %{
        "post" =>
          operation("staffSuspendAccess", "StaffAccountActionResponse", "StaffTargetRequest")
      },
      "/api/v1/staff-accounts/reissue" => %{
        "post" => operation("staffReissue", "StaffAccountActionResponse", "StaffTargetRequest")
      },
      "/api/v1/staff-preferences" => %{
        "get" => operation("staffPreferences", "StaffPreferencesResponse"),
        "post" =>
          operation(
            "staffSetPreferences",
            "StaffAccountActionResponse",
            "StaffPreferencesRequest"
          )
      }
    }
  end

  defp operation(id, response, request \\ nil) do
    base = %{
      "operationId" => id,
      "responses" => %{
        "200" => %{
          "description" => "Safe no-store result",
          "content" => %{"application/json" => %{"schema" => ref(response)}}
        }
      }
    }

    if request,
      do:
        Map.put(base, "requestBody", %{
          "required" => true,
          "content" => %{"application/json" => %{"schema" => ref(request)}}
        }),
      else: base
  end

  defp object(properties),
    do: %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => Map.keys(properties),
      "properties" => properties
    }

  defp array(items), do: %{"type" => "array", "items" => items, "maxItems" => 25}
  defp ref(name), do: %{"$ref" => "#/components/schemas/" <> name}
  defp response(data), do: object(%{"data" => data})
end
