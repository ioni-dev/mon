defmodule MonWeb.OrganizationSettingsController do
  use MonWeb, :controller

  alias Mon.Accounts
  alias MonWeb.OrganizationAuth

  plug :assign_email_and_password_changesets

  def edit(conn, _params) do
    render(conn, "edit.html")
  end

  def update_email(conn, %{"current_password" => password, "organization" => organization_params}) do
    organization = conn.assigns.current_organization

    case Accounts.apply_organization_email(organization, password, organization_params) do
      {:ok, applied_organization} ->
        Accounts.deliver_update_email_instructions(
          applied_organization,
          organization.email,
          &Routes.organization_settings_url(conn, :confirm_email, &1)
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: Routes.organization_settings_path(conn, :edit))

      {:error, changeset} ->
        render(conn, "edit.html", email_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_organization_email(conn.assigns.current_organization, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: Routes.organization_settings_path(conn, :edit))

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: Routes.organization_settings_path(conn, :edit))
    end
  end

  def update_password(conn, %{"current_password" => password, "organization" => organization_params}) do
    organization = conn.assigns.current_organization

    case Accounts.update_organization_password(organization, password, organization_params) do
      {:ok, organization} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:organization_return_to, Routes.organization_settings_path(conn, :edit))
        |> OrganizationAuth.log_in_organization(organization)

      {:error, changeset} ->
        render(conn, "edit.html", password_changeset: changeset)
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    organization = conn.assigns.current_organization

    conn
    |> assign(:email_changeset, Accounts.change_organization_email(organization))
    |> assign(:password_changeset, Accounts.change_organization_password(organization))
  end
end
