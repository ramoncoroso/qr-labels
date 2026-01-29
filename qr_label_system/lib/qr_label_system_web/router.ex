defmodule QrLabelSystemWeb.Router do
  use QrLabelSystemWeb, :router

  import QrLabelSystemWeb.UserAuth
  import QrLabelSystemWeb.Plugs.RBAC
  import QrLabelSystemWeb.Plugs.RateLimiter

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QrLabelSystemWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :rate_limit_api
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug :rate_limit_api
    plug QrLabelSystemWeb.Plugs.ApiAuth, :authenticate_api
  end

  pipeline :admin_only do
    plug :require_admin
  end

  pipeline :operator_only do
    plug :require_operator
  end

  pipeline :rate_limited_login do
    plug :rate_limit_login
  end

  # Public routes
  scope "/", QrLabelSystemWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Development routes
  if Application.compile_env(:qr_label_system, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QrLabelSystemWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes
  scope "/", QrLabelSystemWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{QrLabelSystemWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  # Rate limited login endpoint (separate for rate limiting)
  scope "/", QrLabelSystemWeb do
    pipe_through [:browser, :rate_limited_login, :redirect_if_user_is_authenticated]

    post "/users/log_in/limited", UserSessionController, :create
  end

  scope "/", QrLabelSystemWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{QrLabelSystemWeb.UserAuth, :ensure_authenticated}] do
      # User settings
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email

      # Designs
      live "/designs", DesignLive.Index, :index
      live "/designs/new", DesignLive.Index, :new
      live "/designs/:id", DesignLive.Show, :show
      live "/designs/:id/edit", DesignLive.Editor, :edit

      # Data Sources
      live "/data-sources", DataSourceLive.Index, :index
      live "/data-sources/new", DataSourceLive.Index, :new
      live "/data-sources/:id", DataSourceLive.Show, :show
      live "/data-sources/:id/edit", DataSourceLive.Index, :edit

      # Batches
      live "/batches", BatchLive.Index, :index
      live "/batches/new", BatchLive.New, :new
      live "/batches/:id", BatchLive.Show, :show
      live "/batches/:id/print", BatchLive.Print, :print

      # Generation workflow
      live "/generate", GenerateLive.Index, :index
      live "/generate/design/:design_id", GenerateLive.DataSource, :data_source
      live "/generate/map/:design_id/:source_id", GenerateLive.Mapping, :mapping
      live "/generate/preview/:batch_id", GenerateLive.Preview, :preview
    end
  end

  scope "/", QrLabelSystemWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{QrLabelSystemWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # API routes for JSON endpoints (authenticated + operator role required)
  scope "/api", QrLabelSystemWeb.API do
    pipe_through [:api_auth, :operator_only]

    # Design export/import (operators and admins only)
    get "/designs/:id/export", DesignController, :export
    post "/designs/import", DesignController, :import

    # Data preview (operators and admins only)
    post "/data-sources/:id/preview", DataSourceController, :preview
    post "/data-sources/test-connection", DataSourceController, :test_connection
  end

  # Health check endpoint (public, no auth required)
  scope "/api", QrLabelSystemWeb.API do
    pipe_through :api

    get "/health", HealthController, :check
    get "/health/detailed", HealthController, :detailed
    get "/metrics", HealthController, :metrics
  end

  # Admin dashboard for health and monitoring
  scope "/admin", QrLabelSystemWeb do
    pipe_through [:browser, :require_authenticated_user, :admin_only]

    live_session :admin_dashboard,
      on_mount: [{QrLabelSystemWeb.UserAuth, :ensure_authenticated}] do
      live "/dashboard", Admin.DashboardLive, :index
      live "/users", Admin.UsersLive, :index
      live "/audit", Admin.AuditLive, :index
    end
  end
end
