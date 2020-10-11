defmodule MonWeb.DriverSettingsController do
  use MonWeb, :controller

  alias Mon.Accounts
  alias MonWeb.DriverAuth

  plug :assign_email_and_password_changesets

  def edit(conn, _params) do
    render(conn, "edit.html")
  end

  def update_email(conn, %{"current_password" => password, "driver" => driver_params}) do
    driver = conn.assigns.current_driver

    case Accounts.apply_driver_email(driver, password, driver_params) do
      {:ok, applied_driver} ->
        Accounts.deliver_update_email_instructions(
          applied_driver,
          driver.email,
          &Routes.driver_settings_url(conn, :confirm_email, &1)
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: Routes.driver_settings_path(conn, :edit))

      {:error, changeset} ->
        render(conn, "edit.html", email_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_driver_email(conn.assigns.current_driver, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: Routes.driver_settings_path(conn, :edit))

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: Routes.driver_settings_path(conn, :edit))
    end
  end

  def update_password(conn, %{"current_password" => password, "driver" => driver_params}) do
    driver = conn.assigns.current_driver

    case Accounts.update_driver_password(driver, password, driver_params) do
      {:ok, driver} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:driver_return_to, Routes.driver_settings_path(conn, :edit))
        |> DriverAuth.log_in_driver(driver)

      {:error, changeset} ->
        render(conn, "edit.html", password_changeset: changeset)
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    driver = conn.assigns.current_driver

    conn
    |> assign(:email_changeset, Accounts.change_driver_email(driver))
    |> assign(:password_changeset, Accounts.change_driver_password(driver))
  end
end
