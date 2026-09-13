defmodule AshFoundationLab.Foundation do
  @moduledoc """
  Disposable domain used to pressure-test foundation framework behaviour.
  """

  use Ash.Domain, otp_app: :ash_foundation_lab

  resources do
    resource AshFoundationLab.Actor
    resource AshFoundationLab.FoundationRecord
  end
end
