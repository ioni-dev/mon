defmodule MonWeb.OrganizationRegistrationController do
  use MonWeb, :controller

  alias Mon.Accounts
  alias Mon.Accounts.Organization
  alias MonWeb.OrganizationAuth

  def new(conn, _params) do
    changeset = Accounts.change_organization_registration(%Organization{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"organization" => organization_params}) do
    case Accounts.register_organization(organization_params) do
      {:ok, organization} ->
        {:ok, _} =
          Accounts.deliver_organization_confirmation_instructions(
            organization,
            &Routes.organization_confirmation_url(conn, :confirm, &1)
          )

        conn
        |> put_flash(:info, "Organization created successfully.")
        |> OrganizationAuth.log_in_organization(organization)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
