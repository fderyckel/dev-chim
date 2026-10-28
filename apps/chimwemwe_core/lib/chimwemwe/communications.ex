defmodule Chimwemwe.Communications do
  @moduledoc "Local synthetic staff notices; bounded COMM-1 under ADR 0056."
  use Ash.Domain, otp_app: :chimwemwe_core, validate_config_inclusion?: true

  authorization do
    authorize(:always)
    require_actor?(true)
  end

  resources do
    resource(Chimwemwe.Communications.Notice)
    resource(Chimwemwe.Communications.Preparation)
    resource(Chimwemwe.Communications.Revision)
    resource(Chimwemwe.Communications.Engagement)
  end
end
