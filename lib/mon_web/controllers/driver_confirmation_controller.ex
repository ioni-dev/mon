defmodule MonWeb.DriverConfirmationController do
  use MonWeb, :controller

  alias Mon.Accounts

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"driver" => %{"email" => email}}) do
    if driver = Accounts.get_driver_by_email(email) do
      Accounts.deliver_driver_confirmation_instructions(
        driver,
        &Routes.driver_confirmation_url(conn, :confirm, &1)
      )
    end

    # Regardless of the outcome, show an impartial success/error message.
    conn
    |> put_flash(
      :info,
      "If your email is in our system and it has not been confirmed yet, " <>
        "you will receive an email with instructions shortly."
    )
    |> redirect(to: "/")
  end

  # Do not log in the driver after confirmation to avoid a
  # leaked token giving the driver access to the account.
  def confirm(conn, %{"token" => token}) do
    case Accounts.confirm_driver(token) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Account confirmed successfully.")
        |> redirect(to: "/")

      :error ->
        conn
        |> put_flash(:error, "Confirmation link is invalid or it has expired.")
        |> redirect(to: "/")
    end
  end
end
