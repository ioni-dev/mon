defmodule MonWeb.ClientSettingsController do
  use MonWeb, :controller

  alias Mon.Accounts
  alias MonWeb.ClientAuth

  plug :assign_email_and_password_changesets

  def edit(conn, _params) do
    render(conn, "edit.html")
  end

  def update_email(conn, %{"current_password" => password, "client" => client_params}) do
    client = conn.assigns.current_client

    case Accounts.apply_client_email(client, password, client_params) do
      {:ok, applied_client} ->
        Accounts.deliver_update_email_instructions(
          applied_client,
          client.email,
          &Routes.client_settings_url(conn, :confirm_email, &1)
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: Routes.client_settings_path(conn, :edit))

      {:error, changeset} ->
        render(conn, "edit.html", email_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_client_email(conn.assigns.current_client, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: Routes.client_settings_path(conn, :edit))

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: Routes.client_settings_path(conn, :edit))
    end
  end

  def update_password(conn, %{"current_password" => password, "client" => client_params}) do
    client = conn.assigns.current_client

    case Accounts.update_client_password(client, password, client_params) do
      {:ok, client} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:client_return_to, Routes.client_settings_path(conn, :edit))
        |> ClientAuth.log_in_client(client)

      {:error, changeset} ->
        render(conn, "edit.html", password_changeset: changeset)
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    client = conn.assigns.current_client

    conn
    |> assign(:email_changeset, Accounts.change_client_email(client))
    |> assign(:password_changeset, Accounts.change_client_password(client))
  end
end
