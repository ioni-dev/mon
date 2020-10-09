defmodule MonWeb.ClientResetPasswordController do
  use MonWeb, :controller

  alias Mon.Accounts

  plug :get_client_by_reset_password_token when action in [:edit, :update]

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"client" => %{"email" => email}}) do
    if client = Accounts.get_client_by_email(email) do
      Accounts.deliver_client_reset_password_instructions(
        client,
        &Routes.client_reset_password_url(conn, :edit, &1)
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
    render(conn, "edit.html", changeset: Accounts.change_client_password(conn.assigns.client))
  end

  # Do not log in the client after reset password to avoid a
  # leaked token giving the client access to the account.
  def update(conn, %{"client" => client_params}) do
    case Accounts.reset_client_password(conn.assigns.client, client_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: Routes.client_session_path(conn, :new))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp get_client_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if client = Accounts.get_client_by_reset_password_token(token) do
      conn |> assign(:client, client) |> assign(:token, token)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
