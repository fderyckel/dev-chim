defmodule Chimwemwe.AcademicCalendar do
  @moduledoc """
  Private domain for the institution-owned academic calendar foundation.

  The pure contract validates and previews one exact definition and resolves
  local dates against that candidate. `Chimwemwe.AcademicCalendar.Foundation`
  owns the separately authorized persistent draft and publication actions.

  Tenant context is never accepted as calendar definition input. The writer
  derives it from trusted execution context and keeps all resources closed to
  generic Ash actions.
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
