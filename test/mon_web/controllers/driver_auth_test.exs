defmodule MonWeb.DriverAuthTest do
  use MonWeb.ConnCase, async: true

  alias Mon.Accounts
  alias MonWeb.DriverAuth
  import Mon.AccountsFixtures

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, MonWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{driver: driver_fixture(), conn: conn}
  end

  describe "log_in_driver/3" do
    test "stores the driver token in the session", %{conn: conn, driver: driver} do
      conn = DriverAuth.log_in_driver(conn, driver)
      assert token = get_session(conn, :driver_token)
      assert get_session(conn, :live_socket_id) == "drivers_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == "/"
      assert Accounts.get_driver_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, driver: driver} do
      conn = conn |> put_session(:to_be_removed, "value") |> DriverAuth.log_in_driver(driver)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, driver: driver} do
      conn = conn |> put_session(:driver_return_to, "/hello") |> DriverAuth.log_in_driver(driver)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, driver: driver} do
      conn = conn |> fetch_cookies() |> DriverAuth.log_in_driver(driver, %{"remember_me" => "true"})
      assert get_session(conn, :driver_token) == conn.cookies["driver_remember_me"]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies["driver_remember_me"]
      assert signed_token != get_session(conn, :driver_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_driver/1" do
    test "erases session and cookies", %{conn: conn, driver: driver} do
      driver_token = Accounts.generate_driver_session_token(driver)

      conn =
        conn
        |> put_session(:driver_token, driver_token)
        |> put_req_cookie("driver_remember_me", driver_token)
        |> fetch_cookies()
        |> DriverAuth.log_out_driver()

      refute get_session(conn, :driver_token)
      refute conn.cookies["driver_remember_me"]
      assert %{max_age: 0} = conn.resp_cookies["driver_remember_me"]
      assert redirected_to(conn) == "/"
      refute Accounts.get_driver_by_session_token(driver_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "drivers_sessions:abcdef-token"
      MonWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> DriverAuth.log_out_driver()

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "drivers_sessions:abcdef-token"
      }
    end

    test "works even if driver is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> DriverAuth.log_out_driver()
      refute get_session(conn, :driver_token)
      assert %{max_age: 0} = conn.resp_cookies["driver_remember_me"]
      assert redirected_to(conn) == "/"
    end
  end

  describe "fetch_current_driver/2" do
    test "authenticates driver from session", %{conn: conn, driver: driver} do
      driver_token = Accounts.generate_driver_session_token(driver)
      conn = conn |> put_session(:driver_token, driver_token) |> DriverAuth.fetch_current_driver([])
      assert conn.assigns.current_driver.id == driver.id
    end

    test "authenticates driver from cookies", %{conn: conn, driver: driver} do
      logged_in_conn =
        conn |> fetch_cookies() |> DriverAuth.log_in_driver(driver, %{"remember_me" => "true"})

      driver_token = logged_in_conn.cookies["driver_remember_me"]
      %{value: signed_token} = logged_in_conn.resp_cookies["driver_remember_me"]

      conn =
        conn
        |> put_req_cookie("driver_remember_me", signed_token)
        |> DriverAuth.fetch_current_driver([])

      assert get_session(conn, :driver_token) == driver_token
      assert conn.assigns.current_driver.id == driver.id
    end

    test "does not authenticate if data is missing", %{conn: conn, driver: driver} do
      _ = Accounts.generate_driver_session_token(driver)
      conn = DriverAuth.fetch_current_driver(conn, [])
      refute get_session(conn, :driver_token)
      refute conn.assigns.current_driver
    end
  end

  describe "redirect_if_driver_is_authenticated/2" do
    test "redirects if driver is authenticated", %{conn: conn, driver: driver} do
      conn = conn |> assign(:current_driver, driver) |> DriverAuth.redirect_if_driver_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "does not redirect if driver is not authenticated", %{conn: conn} do
      conn = DriverAuth.redirect_if_driver_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_driver/2" do
    test "redirects if driver is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> DriverAuth.require_authenticated_driver([])
      assert conn.halted
      assert redirected_to(conn) == Routes.driver_session_path(conn, :new)
      assert get_flash(conn, :error) == "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | request_path: "/foo", query_string: ""}
        |> fetch_flash()
        |> DriverAuth.require_authenticated_driver([])

      assert halted_conn.halted
      assert get_session(halted_conn, :driver_return_to) == "/foo"

      halted_conn =
        %{conn | request_path: "/foo", query_string: "bar=baz"}
        |> fetch_flash()
        |> DriverAuth.require_authenticated_driver([])

      assert halted_conn.halted
      assert get_session(halted_conn, :driver_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | request_path: "/foo?bar", method: "POST"}
        |> fetch_flash()
        |> DriverAuth.require_authenticated_driver([])

      assert halted_conn.halted
      refute get_session(halted_conn, :driver_return_to)
    end

    test "does not redirect if driver is authenticated", %{conn: conn, driver: driver} do
      conn = conn |> assign(:current_driver, driver) |> DriverAuth.require_authenticated_driver([])
      refute conn.halted
      refute conn.status
    end
  end
end
