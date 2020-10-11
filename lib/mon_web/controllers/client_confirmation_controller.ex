defmodule MonWeb.ClientConfirmationController do
  use MonWeb, :controller

  alias Mon.Accounts

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"client" => %{"email" => email}}) do
    if client = Accounts.get_client_by_email(email) do
      Accounts.deliver_client_confirmation_instructions(
        client,
        &Routes.client_confirmation_url(conn, :confirm, &1)
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

  # Do not log in the client after confirmation to avoid a
  # leaked token giving the client access to the account.
  def confirm(conn, %{"token" => token}) do
    case Accounts.confirm_client(token) do
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
