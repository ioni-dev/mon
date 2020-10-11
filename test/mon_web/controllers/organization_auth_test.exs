defmodule MonWeb.OrganizationAuthTest do
  use MonWeb.ConnCase, async: true

  alias Mon.Accounts
  alias MonWeb.OrganizationAuth
  import Mon.AccountsFixtures

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, MonWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{organization: organization_fixture(), conn: conn}
  end

  describe "log_in_organization/3" do
    test "stores the organization token in the session", %{conn: conn, organization: organization} do
      conn = OrganizationAuth.log_in_organization(conn, organization)
      assert token = get_session(conn, :organization_token)
      assert get_session(conn, :live_socket_id) == "organizations_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == "/"
      assert Accounts.get_organization_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, organization: organization} do
      conn = conn |> put_session(:to_be_removed, "value") |> OrganizationAuth.log_in_organization(organization)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, organization: organization} do
      conn = conn |> put_session(:organization_return_to, "/hello") |> OrganizationAuth.log_in_organization(organization)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, organization: organization} do
      conn = conn |> fetch_cookies() |> OrganizationAuth.log_in_organization(organization, %{"remember_me" => "true"})
      assert get_session(conn, :organization_token) == conn.cookies["organization_remember_me"]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies["organization_remember_me"]
      assert signed_token != get_session(conn, :organization_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_organization/1" do
    test "erases session and cookies", %{conn: conn, organization: organization} do
      organization_token = Accounts.generate_organization_session_token(organization)

      conn =
        conn
        |> put_session(:organization_token, organization_token)
        |> put_req_cookie("organization_remember_me", organization_token)
        |> fetch_cookies()
        |> OrganizationAuth.log_out_organization()

      refute get_session(conn, :organization_token)
      refute conn.cookies["organization_remember_me"]
      assert %{max_age: 0} = conn.resp_cookies["organization_remember_me"]
      assert redirected_to(conn) == "/"
      refute Accounts.get_organization_by_session_token(organization_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "organizations_sessions:abcdef-token"
      MonWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> OrganizationAuth.log_out_organization()

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "organizations_sessions:abcdef-token"
      }
    end

    test "works even if organization is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> OrganizationAuth.log_out_organization()
      refute get_session(conn, :organization_token)
      assert %{max_age: 0} = conn.resp_cookies["organization_remember_me"]
      assert redirected_to(conn) == "/"
    end
  end

  describe "fetch_current_organization/2" do
    test "authenticates organization from session", %{conn: conn, organization: organization} do
      organization_token = Accounts.generate_organization_session_token(organization)
      conn = conn |> put_session(:organization_token, organization_token) |> OrganizationAuth.fetch_current_organization([])
      assert conn.assigns.current_organization.id == organization.id
    end

    test "authenticates organization from cookies", %{conn: conn, organization: organization} do
      logged_in_conn =
        conn |> fetch_cookies() |> OrganizationAuth.log_in_organization(organization, %{"remember_me" => "true"})

      organization_token = logged_in_conn.cookies["organization_remember_me"]
      %{value: signed_token} = logged_in_conn.resp_cookies["organization_remember_me"]

      conn =
        conn
        |> put_req_cookie("organization_remember_me", signed_token)
        |> OrganizationAuth.fetch_current_organization([])

      assert get_session(conn, :organization_token) == organization_token
      assert conn.assigns.current_organization.id == organization.id
    end

    test "does not authenticate if data is missing", %{conn: conn, organization: organization} do
      _ = Accounts.generate_organization_session_token(organization)
      conn = OrganizationAuth.fetch_current_organization(conn, [])
      refute get_session(conn, :organization_token)
      refute conn.assigns.current_organization
    end
  end

  describe "redirect_if_organization_is_authenticated/2" do
    test "redirects if organization is authenticated", %{conn: conn, organization: organization} do
      conn = conn |> assign(:current_organization, organization) |> OrganizationAuth.redirect_if_organization_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "does not redirect if organization is not authenticated", %{conn: conn} do
      conn = OrganizationAuth.redirect_if_organization_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_organization/2" do
    test "redirects if organization is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> OrganizationAuth.require_authenticated_organization([])
      assert conn.halted
      assert redirected_to(conn) == Routes.organization_session_path(conn, :new)
      assert get_flash(conn, :error) == "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | request_path: "/foo", query_string: ""}
        |> fetch_flash()
        |> OrganizationAuth.require_authenticated_organization([])

      assert halted_conn.halted
      assert get_session(halted_conn, :organization_return_to) == "/foo"

      halted_conn =
        %{conn | request_path: "/foo", query_string: "bar=baz"}
        |> fetch_flash()
        |> OrganizationAuth.require_authenticated_organization([])

      assert halted_conn.halted
      assert get_session(halted_conn, :organization_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | request_path: "/foo?bar", method: "POST"}
        |> fetch_flash()
        |> OrganizationAuth.require_authenticated_organization([])

      assert halted_conn.halted
      refute get_session(halted_conn, :organization_return_to)
    end

    test "does not redirect if organization is authenticated", %{conn: conn, organization: organization} do
      conn = conn |> assign(:current_organization, organization) |> OrganizationAuth.require_authenticated_organization([])
      refute conn.halted
      refute conn.status
    end
  end
end
