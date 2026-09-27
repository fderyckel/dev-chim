defmodule Chimwemwe.Identity do
  @moduledoc """
  Identity and institutional sign-in configuration boundary.

  This domain owns global account identity, revocable authentication tokens, and
  tenant-scoped institutional single-sign-on connection metadata. It is
  intentionally separate from the platform authority domain: authenticating an
  account does not itself grant a role, membership, or capability in a school.
  """

  use Ash.Domain, otp_app: :chimwemwe_core

  resources do
    resource Chimwemwe.Identity.Account
    resource Chimwemwe.Identity.Token
    resource Chimwemwe.Identity.SsoConnection
    resource Chimwemwe.Identity.IdentityConnection
    resource Chimwemwe.Identity.ExternalIdentityLink
    resource Chimwemwe.Identity.Invitation
    resource Chimwemwe.Identity.ApplicationSession
    resource Chimwemwe.Identity.SupportAccessGrant
  end
end
