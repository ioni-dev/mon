defmodule MonWeb.ClientRegistrationController do
  use MonWeb, :controller

  alias Mon.Accounts
  alias Mon.Accounts.Client
  alias MonWeb.ClientAuth

  def new(conn, _params) do
    changeset = Accounts.change_client_registration(%Client{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"client" => client_params}) do
    case Accounts.register_client(client_params) do
      {:ok, client} ->
        {:ok, _} =
          Accounts.deliver_client_confirmation_instructions(
            client,
            &Routes.client_confirmation_url(conn, :confirm, &1)
          )

        conn
        |> put_flash(:info, "Client created successfully.")
        |> ClientAuth.log_in_client(client)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
