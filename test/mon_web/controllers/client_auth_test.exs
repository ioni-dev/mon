defmodule MonWeb.ClientAuthTest do
  use MonWeb.ConnCase, async: true

  alias Mon.Accounts
  alias MonWeb.ClientAuth
  import Mon.AccountsFixtures

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, MonWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{client: client_fixture(), conn: conn}
  end

  describe "log_in_client/3" do
    test "stores the client token in the session", %{conn: conn, client: client} do
      conn = ClientAuth.log_in_client(conn, client)
      assert token = get_session(conn, :client_token)
      assert get_session(conn, :live_socket_id) == "clients_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == "/"
      assert Accounts.get_client_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, client: client} do
      conn = conn |> put_session(:to_be_removed, "value") |> ClientAuth.log_in_client(client)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, client: client} do
      conn = conn |> put_session(:client_return_to, "/hello") |> ClientAuth.log_in_client(client)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, client: client} do
      conn = conn |> fetch_cookies() |> ClientAuth.log_in_client(client, %{"remember_me" => "true"})
      assert get_session(conn, :client_token) == conn.cookies["client_remember_me"]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies["client_remember_me"]
      assert signed_token != get_session(conn, :client_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_client/1" do
    test "erases session and cookies", %{conn: conn, client: client} do
      client_token = Accounts.generate_client_session_token(client)

      conn =
        conn
        |> put_session(:client_token, client_token)
        |> put_req_cookie("client_remember_me", client_token)
        |> fetch_cookies()
        |> ClientAuth.log_out_client()

      refute get_session(conn, :client_token)
      refute conn.cookies["client_remember_me"]
      assert %{max_age: 0} = conn.resp_cookies["client_remember_me"]
      assert redirected_to(conn) == "/"
      refute Accounts.get_client_by_session_token(client_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "clients_sessions:abcdef-token"
      MonWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> ClientAuth.log_out_client()

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "clients_sessions:abcdef-token"
      }
    end

    test "works even if client is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> ClientAuth.log_out_client()
      refute get_session(conn, :client_token)
      assert %{max_age: 0} = conn.resp_cookies["client_remember_me"]
      assert redirected_to(conn) == "/"
    end
  end

  describe "fetch_current_client/2" do
    test "authenticates client from session", %{conn: conn, client: client} do
      client_token = Accounts.generate_client_session_token(client)
      conn = conn |> put_session(:client_token, client_token) |> ClientAuth.fetch_current_client([])
      assert conn.assigns.current_client.id == client.id
    end

    test "authenticates client from cookies", %{conn: conn, client: client} do
      logged_in_conn =
        conn |> fetch_cookies() |> ClientAuth.log_in_client(client, %{"remember_me" => "true"})

      client_token = logged_in_conn.cookies["client_remember_me"]
      %{value: signed_token} = logged_in_conn.resp_cookies["client_remember_me"]

      conn =
        conn
        |> put_req_cookie("client_remember_me", signed_token)
        |> ClientAuth.fetch_current_client([])

      assert get_session(conn, :client_token) == client_token
      assert conn.assigns.current_client.id == client.id
    end

    test "does not authenticate if data is missing", %{conn: conn, client: client} do
      _ = Accounts.generate_client_session_token(client)
      conn = ClientAuth.fetch_current_client(conn, [])
      refute get_session(conn, :client_token)
      refute conn.assigns.current_client
    end
  end

  describe "redirect_if_client_is_authenticated/2" do
    test "redirects if client is authenticated", %{conn: conn, client: client} do
      conn = conn |> assign(:current_client, client) |> ClientAuth.redirect_if_client_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "does not redirect if client is not authenticated", %{conn: conn} do
      conn = ClientAuth.redirect_if_client_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_client/2" do
    test "redirects if client is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> ClientAuth.require_authenticated_client([])
      assert conn.halted
      assert redirected_to(conn) == Routes.client_session_path(conn, :new)
      assert get_flash(conn, :error) == "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | request_path: "/foo", query_string: ""}
        |> fetch_flash()
        |> ClientAuth.require_authenticated_client([])

      assert halted_conn.halted
      assert get_session(halted_conn, :client_return_to) == "/foo"

      halted_conn =
        %{conn | request_path: "/foo", query_string: "bar=baz"}
        |> fetch_flash()
        |> ClientAuth.require_authenticated_client([])

      assert halted_conn.halted
      assert get_session(halted_conn, :client_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | request_path: "/foo?bar", method: "POST"}
        |> fetch_flash()
        |> ClientAuth.require_authenticated_client([])

      assert halted_conn.halted
      refute get_session(halted_conn, :client_return_to)
    end

    test "does not redirect if client is authenticated", %{conn: conn, client: client} do
      conn = conn |> assign(:current_client, client) |> ClientAuth.require_authenticated_client([])
      refute conn.halted
      refute conn.status
    end
  end
end
