defmodule Chimwemwe.InstitutionalStructure do
  @moduledoc "Bounded synthetic root-institution identity, initial operator, and publication."
  use Ash.Domain, otp_app: :chimwemwe_core

  authorization do
    authorize :always
    require_actor? true
  end

  resources do
    resource Chimwemwe.InstitutionalStructure.InstitutionalUnit
    resource Chimwemwe.InstitutionalStructure.InitialOperatorAssignment
    resource Chimwemwe.InstitutionalStructure.InstitutionPublication
  end
end
