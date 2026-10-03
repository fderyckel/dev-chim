defmodule Chimwemwe.OrganizationLegal do
  @moduledoc """
  Tenant-owned corporate/legal structure boundary.

  Slice 2.1-B supplies the reversible synthetic `LegalEntity` foundation.
  ADR 0031 adds the bounded Slice 2.1-C1 relationship, management-reporting
  parentage, and corporate-unit shapes. ADR 0033 adds append-only relationship
  ending and corporate-unit name revision. Educational structures, public
  routes, migration, and real institutional data remain outside this domain.
  """

  use Ash.Domain, otp_app: :chimwemwe_core

  authorization do
    authorize :always
    require_actor? true
  end

  resources do
    resource Chimwemwe.OrganizationLegal.LegalEntity
    resource Chimwemwe.OrganizationLegal.LegalEntityProfileRevision
    resource Chimwemwe.OrganizationLegal.LegalEntityRelationship
    resource Chimwemwe.OrganizationLegal.LegalEntityRelationshipTermination
    resource Chimwemwe.OrganizationLegal.LegalEntityConsolidationParentage
    resource Chimwemwe.OrganizationLegal.CorporateUnit
    resource Chimwemwe.OrganizationLegal.CorporateUnitProfileRevision
  end
end
