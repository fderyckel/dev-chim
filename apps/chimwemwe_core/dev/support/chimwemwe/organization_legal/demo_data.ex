defmodule Chimwemwe.OrganizationLegal.DemoData do
  @moduledoc """
  Deterministic, non-sensitive data for the local Phase 2.1-C2a demonstration.

  The aliases mirror the linked-structure review packet. This dataset persists
  legal-entity identities and profiles plus the bounded relationships,
  management-reporting parentage, and corporate units authorized by ADR 0031,
  then exercises the append-only lifecycle actions authorized by ADR 0033. It
  creates no educational, operator, site, statutory-consolidation, or real-data
  relationship; ADR 0025 conditions C25-03 through C25-06 remain open.
  """

  alias Chimwemwe.Platform.{ExecutionContext, TrustedActor, TrustedPlacement}

  @tenant_id "81000000-0000-4000-8000-000000000001"
  @actor_id "81aa0000-0000-4000-8000-000000000001"
  @routing_version 1
  @placement_ref "organization-legal-local-demo"

  @entities [
    %{
      key: "LE-GROUP",
      official_name: "Mphamvu Learning Holdings Limited",
      display_name: "Mphamvu Learning Holdings",
      idempotency_key: "81810000-0000-4000-8000-000000000001",
      causation_id: "81820000-0000-4000-8000-000000000001"
    },
    %{
      key: "LE-OPS",
      official_name: "Mphamvu Education Operations Limited",
      display_name: "Mphamvu Education Operations",
      idempotency_key: "81810000-0000-4000-8000-000000000002",
      causation_id: "81820000-0000-4000-8000-000000000002"
    },
    %{
      key: "LE-PROPERTY",
      official_name: "Mphamvu Property Foundation",
      display_name: "Mphamvu Property Foundation",
      idempotency_key: "81810000-0000-4000-8000-000000000003",
      causation_id: "81820000-0000-4000-8000-000000000003"
    },
    %{
      key: "LE-JOINT",
      official_name: "Community Education Trust",
      display_name: "Community Education Trust",
      idempotency_key: "81810000-0000-4000-8000-000000000004",
      causation_id: "81820000-0000-4000-8000-000000000004"
    },
    %{
      key: "LE-NEW-OPS",
      official_name: "Mphamvu New Education Operations Limited",
      display_name: "Mphamvu New Education Operations",
      idempotency_key: "81810000-0000-4000-8000-000000000005",
      causation_id: "81820000-0000-4000-8000-000000000005"
    },
    %{
      key: "LE-INDEPENDENT",
      official_name: "Chisomo Independent Academy Trust",
      display_name: "Chisomo Academy Trust",
      idempotency_key: "81810000-0000-4000-8000-000000000006",
      causation_id: "81820000-0000-4000-8000-000000000006"
    }
  ]

  @relationships [
    %{
      key: "REL-GROUP-OPS-EQUITY",
      source_key: "LE-GROUP",
      target_key: "LE-OPS",
      relationship_type: :equity_interest,
      basis_key: :registered_equity,
      interest_bps: 10_000,
      effective_from: ~D[2026-10-03],
      evidence_reference: "SYNTHETIC:GROUP-OPS-EQUITY",
      idempotency_key: "81830000-0000-4000-8000-000000000001",
      causation_id: "81840000-0000-4000-8000-000000000001"
    },
    %{
      key: "REL-GROUP-NEW-OPS-EQUITY",
      source_key: "LE-GROUP",
      target_key: "LE-NEW-OPS",
      relationship_type: :equity_interest,
      basis_key: :registered_equity,
      interest_bps: 5_000,
      effective_from: ~D[2026-10-03],
      evidence_reference: "SYNTHETIC:GROUP-NEW-OPS-EQUITY",
      idempotency_key: "81830000-0000-4000-8000-000000000002",
      causation_id: "81840000-0000-4000-8000-000000000002"
    },
    %{
      key: "REL-JOINT-NEW-OPS-EQUITY",
      source_key: "LE-JOINT",
      target_key: "LE-NEW-OPS",
      relationship_type: :equity_interest,
      basis_key: :registered_equity,
      interest_bps: 5_000,
      effective_from: ~D[2026-10-03],
      evidence_reference: "SYNTHETIC:JOINT-NEW-OPS-EQUITY",
      idempotency_key: "81830000-0000-4000-8000-000000000003",
      causation_id: "81840000-0000-4000-8000-000000000003"
    },
    %{
      key: "REL-GROUP-PROPERTY-APPOINTMENT",
      source_key: "LE-GROUP",
      target_key: "LE-PROPERTY",
      relationship_type: :governing_body_appointment,
      basis_key: :governing_instrument,
      interest_bps: nil,
      effective_from: ~D[2026-10-03],
      evidence_reference: "SYNTHETIC:GROUP-PROPERTY-APPOINTMENT",
      idempotency_key: "81830000-0000-4000-8000-000000000004",
      causation_id: "81840000-0000-4000-8000-000000000004"
    }
  ]

  @consolidation_parentages [
    %{
      key: "CONSOLIDATION-OPS-GROUP",
      child_key: "LE-OPS",
      parent_key: "LE-GROUP",
      effective_from: ~D[2026-10-03],
      evidence_reference: "SYNTHETIC:OPS-MANAGEMENT-REPORTING",
      idempotency_key: "81850000-0000-4000-8000-000000000001",
      causation_id: "81860000-0000-4000-8000-000000000001"
    },
    %{
      key: "CONSOLIDATION-PROPERTY-GROUP",
      child_key: "LE-PROPERTY",
      parent_key: "LE-GROUP",
      effective_from: ~D[2026-10-03],
      evidence_reference: "SYNTHETIC:PROPERTY-MANAGEMENT-REPORTING",
      idempotency_key: "81850000-0000-4000-8000-000000000002",
      causation_id: "81860000-0000-4000-8000-000000000002"
    },
    %{
      key: "CONSOLIDATION-NEW-OPS-GROUP",
      child_key: "LE-NEW-OPS",
      parent_key: "LE-GROUP",
      effective_from: ~D[2026-10-03],
      evidence_reference: "SYNTHETIC:NEW-OPS-MANAGEMENT-REPORTING",
      idempotency_key: "81850000-0000-4000-8000-000000000003",
      causation_id: "81860000-0000-4000-8000-000000000003"
    }
  ]

  @corporate_units [
    %{
      key: "CU-GROUP-SHARED",
      legal_entity_key: "LE-GROUP",
      parent_key: nil,
      official_name: "Group Shared Services",
      display_name: "Shared Services",
      idempotency_key: "81870000-0000-4000-8000-000000000001",
      causation_id: "81880000-0000-4000-8000-000000000001"
    },
    %{
      key: "CU-GROUP-FINANCE",
      legal_entity_key: "LE-GROUP",
      parent_key: "CU-GROUP-SHARED",
      official_name: "Group Finance Operations",
      display_name: "Finance",
      idempotency_key: "81870000-0000-4000-8000-000000000002",
      causation_id: "81880000-0000-4000-8000-000000000002"
    },
    %{
      key: "CU-GROUP-GOVERNANCE",
      legal_entity_key: "LE-GROUP",
      parent_key: "CU-GROUP-SHARED",
      official_name: "Group Governance and Assurance",
      display_name: "Governance & Assurance",
      idempotency_key: "81870000-0000-4000-8000-000000000003",
      causation_id: "81880000-0000-4000-8000-000000000003"
    },
    %{
      key: "CU-OPS-SCHOOLS",
      legal_entity_key: "LE-OPS",
      parent_key: nil,
      official_name: "School Operations",
      display_name: "School Operations",
      idempotency_key: "81870000-0000-4000-8000-000000000004",
      causation_id: "81880000-0000-4000-8000-000000000004"
    },
    %{
      key: "CU-PROPERTY-ESTATES",
      legal_entity_key: "LE-PROPERTY",
      parent_key: nil,
      official_name: "Property and Estates",
      display_name: "Estates",
      idempotency_key: "81870000-0000-4000-8000-000000000005",
      causation_id: "81880000-0000-4000-8000-000000000005"
    },
    %{
      key: "CU-NEW-OPS-JOINT",
      legal_entity_key: "LE-NEW-OPS",
      parent_key: nil,
      official_name: "Joint Education Operations",
      display_name: "Joint Operations",
      idempotency_key: "81870000-0000-4000-8000-000000000006",
      causation_id: "81880000-0000-4000-8000-000000000006"
    }
  ]

  @relationship_terminations [
    %{
      key: "REL-GROUP-PROPERTY-APPOINTMENT-END",
      relationship_key: "REL-GROUP-PROPERTY-APPOINTMENT",
      expected_version: 1,
      effective_until: ~D[2027-06-30],
      evidence_reference: "SYNTHETIC:GROUP-PROPERTY-APPOINTMENT-END",
      idempotency_key: "81890000-0000-4000-8000-000000000001",
      causation_id: "818a0000-0000-4000-8000-000000000001"
    }
  ]

  @corporate_unit_profile_revisions [
    %{
      key: "CU-GROUP-SHARED-NAME-REVISION",
      corporate_unit_key: "CU-GROUP-SHARED",
      expected_version: 1,
      official_name: "Mphamvu Group Shared Services",
      display_name: "Group Shared Services",
      idempotency_key: "818b0000-0000-4000-8000-000000000001",
      causation_id: "818c0000-0000-4000-8000-000000000001"
    }
  ]

  @spec tenant_id() :: String.t()
  def tenant_id, do: @tenant_id

  @spec actor_id() :: String.t()
  def actor_id, do: @actor_id

  @spec entities() :: [map()]
  def entities, do: @entities

  @spec relationships() :: [map()]
  def relationships, do: @relationships

  @spec consolidation_parentages() :: [map()]
  def consolidation_parentages, do: @consolidation_parentages

  @spec corporate_units() :: [map()]
  def corporate_units, do: @corporate_units

  @spec relationship_terminations() :: [map()]
  def relationship_terminations, do: @relationship_terminations

  @spec corporate_unit_profile_revisions() :: [map()]
  def corporate_unit_profile_revisions, do: @corporate_unit_profile_revisions

  @spec placements() :: [keyword()]
  def placements do
    [
      [
        tenant_id: @tenant_id,
        routing_version: @routing_version,
        profile: :pooled,
        placement_ref: @placement_ref,
        repository: :organization_legal_demo
      ]
    ]
  end

  @spec context() :: ExecutionContext.t()
  def context do
    {:ok, actor} =
      TrustedActor.establish(
        actor_id: @actor_id,
        tenant_id: @tenant_id,
        assurance: "local_synthetic"
      )

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: @tenant_id,
        routing_version: @routing_version,
        profile: :pooled,
        placement_ref: @placement_ref
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: Ecto.UUID.generate(),
        purpose: "phase2.1c.local_demo",
        locale: "en"
      )

    context
  end
end
