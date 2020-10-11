defmodule MonWeb.DriverSessionController do
  use MonWeb, :controller

  alias Mon.Accounts
  alias MonWeb.DriverAuth

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"driver" => driver_params}) do
    %{"email" => email, "password" => password} = driver_params

    if driver = Accounts.get_driver_by_email_and_password(email, password) do
      DriverAuth.log_in_driver(conn, driver, driver_params)
    else
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> DriverAuth.log_out_driver()
  end
end
