defmodule MonWeb.DriverSessionControllerTest do
  use MonWeb.ConnCase, async: true

  import Mon.AccountsFixtures

  setup do
    %{driver: driver_fixture()}
  end

  describe "GET /drivers/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, Routes.driver_session_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Log in</a>"
      assert response =~ "Register</a>"
    end

    test "redirects if already logged in", %{conn: conn, driver: driver} do
      conn = conn |> log_in_driver(driver) |> get(Routes.driver_session_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /drivers/log_in" do
    test "logs the driver in", %{conn: conn, driver: driver} do
      conn =
        post(conn, Routes.driver_session_path(conn, :create), %{
          "driver" => %{"email" => driver.email, "password" => valid_driver_password()}
        })

      assert get_session(conn, :driver_token)
      assert redirected_to(conn) =~ "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ driver.email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "logs the driver in with remember me", %{conn: conn, driver: driver} do
      conn =
        post(conn, Routes.driver_session_path(conn, :create), %{
          "driver" => %{
            "email" => driver.email,
            "password" => valid_driver_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["driver_remember_me"]
      assert redirected_to(conn) =~ "/"
    end

    test "emits error message with invalid credentials", %{conn: conn, driver: driver} do
      conn =
        post(conn, Routes.driver_session_path(conn, :create), %{
          "driver" => %{"email" => driver.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /drivers/log_out" do
    test "logs the driver out", %{conn: conn, driver: driver} do
      conn = conn |> log_in_driver(driver) |> delete(Routes.driver_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :driver_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the driver is not logged in", %{conn: conn} do
      conn = delete(conn, Routes.driver_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :driver_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
