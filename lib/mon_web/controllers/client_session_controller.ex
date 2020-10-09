defmodule MonWeb.ClientSessionController do
  use MonWeb, :controller

  alias Mon.Accounts
  alias MonWeb.ClientAuth

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"client" => client_params}) do
    %{"email" => email, "password" => password} = client_params

    if client = Accounts.get_client_by_email_and_password(email, password) do
      ClientAuth.log_in_client(conn, client, client_params)
    else
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> ClientAuth.log_out_client()
  end
end
