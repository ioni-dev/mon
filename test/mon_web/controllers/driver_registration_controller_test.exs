defmodule MonWeb.DriverRegistrationControllerTest do
  use MonWeb.ConnCase, async: true

  import Mon.AccountsFixtures

  describe "GET /drivers/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, Routes.driver_registration_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "Log in</a>"
      assert response =~ "Register</a>"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_driver(driver_fixture()) |> get(Routes.driver_registration_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /drivers/register" do
    @tag :capture_log
    test "creates account and logs the driver in", %{conn: conn} do
      email = unique_driver_email()

      conn =
        post(conn, Routes.driver_registration_path(conn, :create), %{
          "driver" => %{"email" => email, "password" => valid_driver_password()}
        })

      assert get_session(conn, :driver_token)
      assert redirected_to(conn) =~ "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, Routes.driver_registration_path(conn, :create), %{
          "driver" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
