defmodule MonWeb.OrganizationSessionController do
  use MonWeb, :controller

  alias Mon.Accounts
  alias MonWeb.OrganizationAuth

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"organization" => organization_params}) do
    %{"email" => email, "password" => password} = organization_params

    if organization = Accounts.get_organization_by_email_and_password(email, password) do
      OrganizationAuth.log_in_organization(conn, organization, organization_params)
    else
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> OrganizationAuth.log_out_organization()
  end
end
