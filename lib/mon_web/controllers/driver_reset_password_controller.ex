defmodule MonWeb.DriverResetPasswordController do
  use MonWeb, :controller

  alias Mon.Accounts

  plug :get_driver_by_reset_password_token when action in [:edit, :update]

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"driver" => %{"email" => email}}) do
    if driver = Accounts.get_driver_by_email(email) do
      Accounts.deliver_driver_reset_password_instructions(
        driver,
        &Routes.driver_reset_password_url(conn, :edit, &1)
      )
    end

    # Regardless of the outcome, show an impartial success/error message.
    conn
    |> put_flash(
      :info,
      "If your email is in our system, you will receive instructions to reset your password shortly."
    )
    |> redirect(to: "/")
  end

  def edit(conn, _params) do
    render(conn, "edit.html", changeset: Accounts.change_driver_password(conn.assigns.driver))
  end

  # Do not log in the driver after reset password to avoid a
  # leaked token giving the driver access to the account.
  def update(conn, %{"driver" => driver_params}) do
    case Accounts.reset_driver_password(conn.assigns.driver, driver_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: Routes.driver_session_path(conn, :new))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp get_driver_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if driver = Accounts.get_driver_by_reset_password_token(token) do
      conn |> assign(:driver, driver) |> assign(:token, token)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
