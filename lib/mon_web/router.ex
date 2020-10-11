defmodule MonWeb.Router do
  use MonWeb, :router

  import MonWeb.OrganizationAuth

  import MonWeb.ClientAuth

  import MonWeb.DriverAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_organization
    plug :fetch_current_client
    plug :fetch_current_driver
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MonWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", MonWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: MonWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", MonWeb do
    pipe_through [:browser, :redirect_if_driver_is_authenticated]

    get "/drivers/register", DriverRegistrationController, :new
    post "/drivers/register", DriverRegistrationController, :create
    get "/drivers/log_in", DriverSessionController, :new
    post "/drivers/log_in", DriverSessionController, :create
    get "/drivers/reset_password", DriverResetPasswordController, :new
    post "/drivers/reset_password", DriverResetPasswordController, :create
    get "/drivers/reset_password/:token", DriverResetPasswordController, :edit
    put "/drivers/reset_password/:token", DriverResetPasswordController, :update
  end

  scope "/", MonWeb do
    pipe_through [:browser, :require_authenticated_driver]

    get "/drivers/settings", DriverSettingsController, :edit
    put "/drivers/settings/update_password", DriverSettingsController, :update_password
    put "/drivers/settings/update_email", DriverSettingsController, :update_email
    get "/drivers/settings/confirm_email/:token", DriverSettingsController, :confirm_email
  end

  scope "/", MonWeb do
    pipe_through [:browser]

    delete "/drivers/log_out", DriverSessionController, :delete
    get "/drivers/confirm", DriverConfirmationController, :new
    post "/drivers/confirm", DriverConfirmationController, :create
    get "/drivers/confirm/:token", DriverConfirmationController, :confirm
  end

  ## Authentication routes

  scope "/", MonWeb do
    pipe_through [:browser, :redirect_if_client_is_authenticated]

    get "/clients/register", ClientRegistrationController, :new
    post "/clients/register", ClientRegistrationController, :create
    get "/clients/log_in", ClientSessionController, :new
    post "/clients/log_in", ClientSessionController, :create
    get "/clients/reset_password", ClientResetPasswordController, :new
    post "/clients/reset_password", ClientResetPasswordController, :create
    get "/clients/reset_password/:token", ClientResetPasswordController, :edit
    put "/clients/reset_password/:token", ClientResetPasswordController, :update
  end

  scope "/", MonWeb do
    pipe_through [:browser, :require_authenticated_client]

    get "/clients/settings", ClientSettingsController, :edit
    put "/clients/settings/update_password", ClientSettingsController, :update_password
    put "/clients/settings/update_email", ClientSettingsController, :update_email
    get "/clients/settings/confirm_email/:token", ClientSettingsController, :confirm_email
  end

  scope "/", MonWeb do
    pipe_through [:browser]

    delete "/clients/log_out", ClientSessionController, :delete
    get "/clients/confirm", ClientConfirmationController, :new
    post "/clients/confirm", ClientConfirmationController, :create
    get "/clients/confirm/:token", ClientConfirmationController, :confirm
  end

  ## Authentication routes

  scope "/", MonWeb do
    pipe_through [:browser, :redirect_if_organization_is_authenticated]

    get "/organizations/register", OrganizationRegistrationController, :new
    post "/organizations/register", OrganizationRegistrationController, :create
    get "/organizations/log_in", OrganizationSessionController, :new
    post "/organizations/log_in", OrganizationSessionController, :create
    get "/organizations/reset_password", OrganizationResetPasswordController, :new
    post "/organizations/reset_password", OrganizationResetPasswordController, :create
    get "/organizations/reset_password/:token", OrganizationResetPasswordController, :edit
    put "/organizations/reset_password/:token", OrganizationResetPasswordController, :update
  end

  scope "/", MonWeb do
    pipe_through [:browser, :require_authenticated_organization]

    get "/organizations/settings", OrganizationSettingsController, :edit
    put "/organizations/settings/update_password", OrganizationSettingsController, :update_password
    put "/organizations/settings/update_email", OrganizationSettingsController, :update_email
    get "/organizations/settings/confirm_email/:token", OrganizationSettingsController, :confirm_email
  end

  scope "/", MonWeb do
    pipe_through [:browser]

    delete "/organizations/log_out", OrganizationSessionController, :delete
    get "/organizations/confirm", OrganizationConfirmationController, :new
    post "/organizations/confirm", OrganizationConfirmationController, :create
    get "/organizations/confirm/:token", OrganizationConfirmationController, :confirm
  end
end
