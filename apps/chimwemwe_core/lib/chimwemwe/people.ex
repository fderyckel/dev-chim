defmodule Chimwemwe.People do
  @moduledoc "Private synthetic people and participation domain; ADR 0036."
  use Ash.Domain, otp_app: :chimwemwe_core, validate_config_inclusion?: true

  authorization do
    authorize :always
    require_actor? true
  end

  resources do
    resource Chimwemwe.People.Person
    resource Chimwemwe.People.Participation
    resource Chimwemwe.People.StaffAccountAssociation
  end
end
