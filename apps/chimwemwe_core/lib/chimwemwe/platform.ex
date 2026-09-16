defmodule Chimwemwe.Platform do
  @moduledoc """
  The mandatory platform domain shared by later business modules.

  Its empty resource list remains deliberate through slice 1C. The base-resource,
  resource-audit, descriptor, and trusted read-invocation guardrails are present, but
  production resources arrive only with an owned capability and its tenant,
  authorization, persistence, migration, and lifecycle contract.
  """

  use Ash.Domain, otp_app: :chimwemwe_core

  authorization do
    authorize :always
    require_actor? true
  end

  resources do
  end
end
