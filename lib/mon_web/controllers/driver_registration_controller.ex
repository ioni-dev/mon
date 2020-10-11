defmodule MonWeb.DriverRegistrationController do
  use MonWeb, :controller

  alias Mon.Accounts
  alias Mon.Accounts.Driver
  alias MonWeb.DriverAuth

  def new(conn, _params) do
    changeset = Accounts.change_driver_registration(%Driver{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"driver" => driver_params}) do
    case Accounts.register_driver(driver_params) do
      {:ok, driver} ->
        {:ok, _} =
          Accounts.deliver_driver_confirmation_instructions(
            driver,
            &Routes.driver_confirmation_url(conn, :confirm, &1)
          )

        conn
        |> put_flash(:info, "Driver created successfully.")
        |> DriverAuth.log_in_driver(driver)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
