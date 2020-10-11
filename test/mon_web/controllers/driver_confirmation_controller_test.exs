defmodule MonWeb.DriverConfirmationControllerTest do
  use MonWeb.ConnCase, async: true

  alias Mon.Accounts
  alias Mon.Repo
  import Mon.AccountsFixtures

  setup do
    %{driver: driver_fixture()}
  end

  describe "GET /drivers/confirm" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.driver_confirmation_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /drivers/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, driver: driver} do
      conn =
        post(conn, Routes.driver_confirmation_path(conn, :create), %{
          "driver" => %{"email" => driver.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Accounts.DriverToken, driver_id: driver.id).context == "confirm"
    end

    test "does not send confirmation token if account is confirmed", %{conn: conn, driver: driver} do
      Repo.update!(Accounts.Driver.confirm_changeset(driver))

      conn =
        post(conn, Routes.driver_confirmation_path(conn, :create), %{
          "driver" => %{"email" => driver.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(Accounts.DriverToken, driver_id: driver.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.driver_confirmation_path(conn, :create), %{
          "driver" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.DriverToken) == []
    end
  end

  describe "GET /drivers/confirm/:token" do
    test "confirms the given token once", %{conn: conn, driver: driver} do
      token =
        extract_driver_token(fn url ->
          Accounts.deliver_driver_confirmation_instructions(driver, url)
        end)

      conn = get(conn, Routes.driver_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "Account confirmed successfully"
      assert Accounts.get_driver!(driver.id).confirmed_at
      refute get_session(conn, :driver_token)
      assert Repo.all(Accounts.DriverToken) == []

      conn = get(conn, Routes.driver_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Confirmation link is invalid or it has expired"
    end

    test "does not confirm email with invalid token", %{conn: conn, driver: driver} do
      conn = get(conn, Routes.driver_confirmation_path(conn, :confirm, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Confirmation link is invalid or it has expired"
      refute Accounts.get_driver!(driver.id).confirmed_at
    end
  end
end
