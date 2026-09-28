defmodule Chimwemwe.OrganizationLegal do
  @moduledoc """
  Tenant-owned corporate/legal structure boundary.

  Slice 2.1-B intentionally contains only the reversible synthetic
  `LegalEntity` foundation. Legal relationships, corporate units, educational
  structures, public routes, migration, and real institutional data remain
  outside this domain until their separate gates pass.
  """

  use Ash.Domain, otp_app: :chimwemwe_core

  authorization do
    authorize :always
    require_actor? true
  end

  resources do
    resource Chimwemwe.OrganizationLegal.LegalEntity
    resource Chimwemwe.OrganizationLegal.LegalEntityProfileRevision
  end
end
