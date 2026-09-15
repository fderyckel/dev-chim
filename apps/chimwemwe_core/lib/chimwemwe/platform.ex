defmodule Chimwemwe.Platform do
  @moduledoc """
  The mandatory platform domain shared by later business modules.

  Its empty resource list is deliberate in slice 1A. Production resources arrive only
  with an owned capability and its tenant, authorization, persistence, and lifecycle
  contract.
  """

  use Ash.Domain, otp_app: :chimwemwe_core

  authorization do
    authorize :always
  end

  resources do
  end
end
