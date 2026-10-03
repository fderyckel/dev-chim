defmodule Chimwemwe.AcademicCalendar do
  @moduledoc """
  Executable contract for the first institution-owned academic calendar slice.

  This module validates and previews one exact calendar definition and resolves
  local dates against that candidate. It deliberately performs no persistence
  or publication: those actions remain behind the institutional-unit and
  primary-operator eligibility boundary described by ADRs 0021, 0034, and 0035.

  Tenant context is therefore not accepted as calendar input. The later named
  writer action must derive it from trusted execution context, verify that the
  exact institutional unit belongs to it, and persist the accepted definition
  with audit, outbox, idempotency, and optimistic-concurrency evidence.
  """

  use Ash.Domain, otp_app: :chimwemwe_core

  alias Chimwemwe.AcademicCalendar.{Contract, Error, Preview, Resolution}

  authorization do
    authorize :always
    require_actor? true
  end

  resources do
    resource Chimwemwe.AcademicCalendar.Calendar
    resource Chimwemwe.AcademicCalendar.AcademicYear
    resource Chimwemwe.AcademicCalendar.AcademicPeriod
    resource Chimwemwe.AcademicCalendar.CalendarClosure
  end

  @doc "Validates and canonicalizes one publication candidate without mutation."
  @spec preview_publication(map()) :: {:ok, Preview.t()} | {:error, Error.t()}
  defdelegate preview_publication(input), to: Contract

  @doc "Resolves one local date against the exact canonical preview."
  @spec resolve_date(Preview.t(), Date.t()) ::
          {:ok, Resolution.t()} | {:error, Error.t()}
  defdelegate resolve_date(preview, local_date), to: Contract
end
