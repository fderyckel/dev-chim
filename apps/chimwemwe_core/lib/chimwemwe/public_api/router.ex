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
