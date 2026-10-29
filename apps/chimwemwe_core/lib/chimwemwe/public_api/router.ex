defmodule Chimwemwe.PublicApi.Router do
  @moduledoc false

  use Phoenix.Router

  pipeline :callback do
    plug(:accepts, ["json"])
    plug(Chimwemwe.PublicApi.SecurityHeadersPlug)
  end

  pipeline :authenticated do
    plug(:accepts, ["json"])
    plug(:fetch_cookies)
    plug(Chimwemwe.PublicApi.SecurityHeadersPlug)
    plug(Chimwemwe.PublicApi.SessionPlug)
  end

  pipeline :unsafe do
    plug(Chimwemwe.PublicApi.OriginCsrfPlug)
  end

  pipeline :local_classroom do
    plug(Chimwemwe.PublicApi.ClassroomPlug)
  end

  pipeline :local_calendar do
    plug(Chimwemwe.PublicApi.CalendarPlug)
  end

  pipeline :local_communications do
    plug(Chimwemwe.PublicApi.CommunicationsPlug)
  end

  pipeline :local_staff do
    plug(Chimwemwe.PublicApi.StaffGuard)
  end

  scope "/api/v1/communications", Chimwemwe.PublicApi do
    pipe_through([:local_communications, :authenticated])
    get("/workspace", CommunicationsController, :workspace, log: false)
    get("/draft", CommunicationsController, :inspect_draft, log: false)
    get("/review", CommunicationsController, :review_operation, log: false)
    get("/status", CommunicationsController, :recipient_status, log: false)
    get("/metrics", CommunicationsController, :metrics, log: false)
    get("/receipt", CommunicationsController, :receipt, log: false)
  end

  scope "/api/v1/communications", Chimwemwe.PublicApi do
    pipe_through([:local_communications, :authenticated, :unsafe])
    post("/create-draft", CommunicationsController, :create_draft, log: false)
    post("/revise-draft", CommunicationsController, :revise_draft, log: false)
    post("/prepare-operation", CommunicationsController, :prepare_operation, log: false)
    post("/submit-for-approval", CommunicationsController, :submit_for_approval, log: false)
    post("/approve-operation", CommunicationsController, :approve_operation, log: false)
    post("/open-notice", CommunicationsController, :open_notice, log: false)
    post("/confirm-receipt", CommunicationsController, :confirm_receipt, log: false)
    post("/command-outcome", CommunicationsController, :command_outcome, log: false)
  end

  scope "/api/v1", Chimwemwe.PublicApi do
    pipe_through([:callback, :local_staff])
    get("/staff-login", StaffLoginController, :show, log: false)
    post("/staff-login", StaffLoginController, :create, log: false)
    post("/staff-login/cancel", StaffLoginController, :cancel, log: false)
    post("/staff-login/replace-password", StaffLoginController, :replace_password, log: false)
  end

  scope "/api/v1", Chimwemwe.PublicApi do
    pipe_through([:local_staff, :authenticated])
    get("/staff-accounts", StaffAccountsController, :index, log: false)
    get("/staff-preferences", StaffAccountsController, :preferences, log: false)
  end

  scope "/api/v1", Chimwemwe.PublicApi do
    pipe_through([:local_staff, :authenticated, :unsafe])
    post("/staff-accounts/provision", StaffAccountsController, :provision, log: false)
    post("/staff-accounts/revise-details", StaffAccountsController, :revise_details, log: false)
    post("/staff-accounts/set-access", StaffAccountsController, :set_access, log: false)

    post("/staff-accounts/revoke-access-profile", StaffAccountsController, :revoke_access_profile,
      log: false
    )

    post("/staff-accounts/suspend-access", StaffAccountsController, :suspend_access, log: false)
    post("/staff-accounts/reissue", StaffAccountsController, :reissue, log: false)
    post("/staff-preferences", StaffAccountsController, :set_preferences, log: false)
  end

  scope "/api/v1/calendar", Chimwemwe.PublicApi do
    pipe_through([:local_calendar, :authenticated])
    get("/preparation", CalendarController, :show, log: false)
  end

  scope "/api/v1/calendar", Chimwemwe.PublicApi do
    pipe_through([:local_calendar, :authenticated, :unsafe])
    post("/save-draft", CalendarController, :save, log: false)
    post("/publish", CalendarController, :publish, log: false)
    post("/resolve", CalendarController, :resolve, log: false)
  end

  scope "/api/v1/classroom", Chimwemwe.PublicApi do
    pipe_through([:local_classroom, :authenticated])
    get("/classes", ClassroomController, :classes, log: false)
    get("/preparation", ClassroomController, :preparation, log: false)
  end

  scope "/api/v1/classroom", Chimwemwe.PublicApi do
    pipe_through([:local_classroom, :authenticated, :unsafe])
    post("/prepare-attendance", ClassroomController, :prepare, log: false)
    post("/submit-attendance", ClassroomController, :submit, log: false)
    post("/correct-attendance", ClassroomController, :correct, log: false)
    post("/prepare-class", ClassroomController, :prepare_class, log: false)
    post("/add-student", ClassroomController, :add_student, log: false)
  end

  scope "/auth", Chimwemwe.PublicApi do
    pipe_through(:callback)

    get("/sign-in", SignInController, :show)
    get("/callback", CallbackController, :show)
  end

  scope "/api/v1", Chimwemwe.PublicApi do
    pipe_through(:authenticated)

    get("/session", SessionController, :show)
  end

  scope "/api/v1", Chimwemwe.PublicApi do
    pipe_through([:authenticated, :unsafe])

    post("/session/logout", SessionController, :logout)
    post("/session/support/elevate", SessionController, :elevate)
  end
end
