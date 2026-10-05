defmodule Chimwemwe.Classroom do
  @moduledoc "Private synthetic classroom setup domain; ADR 0037."
  use Ash.Domain, otp_app: :chimwemwe_core, validate_config_inclusion?: true

  authorization do
    authorize :always
    require_actor? true
  end

  resources do
    resource Chimwemwe.Classroom.ClassRegister
    resource Chimwemwe.Classroom.Enrolment
    resource Chimwemwe.Classroom.TeachingAssignment
    resource Chimwemwe.Classroom.Placement
  end
end
