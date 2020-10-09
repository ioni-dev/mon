defmodule MonWeb.OrganizationSessionControllerTest do
  use MonWeb.ConnCase, async: true

  import Mon.AccountsFixtures

  setup do
    %{organization: organization_fixture()}
  end

  describe "GET /organizations/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, Routes.organization_session_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Log in</a>"
      assert response =~ "Register</a>"
    end

    test "redirects if already logged in", %{conn: conn, organization: organization} do
      conn = conn |> log_in_organization(organization) |> get(Routes.organization_session_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /organizations/log_in" do
    test "logs the organization in", %{conn: conn, organization: organization} do
      conn =
        post(conn, Routes.organization_session_path(conn, :create), %{
          "organization" => %{"email" => organization.email, "password" => valid_organization_password()}
        })

      assert get_session(conn, :organization_token)
      assert redirected_to(conn) =~ "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ organization.email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "logs the organization in with remember me", %{conn: conn, organization: organization} do
      conn =
        post(conn, Routes.organization_session_path(conn, :create), %{
          "organization" => %{
            "email" => organization.email,
            "password" => valid_organization_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["organization_remember_me"]
      assert redirected_to(conn) =~ "/"
    end

    test "emits error message with invalid credentials", %{conn: conn, organization: organization} do
      conn =
        post(conn, Routes.organization_session_path(conn, :create), %{
          "organization" => %{"email" => organization.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /organizations/log_out" do
    test "logs the organization out", %{conn: conn, organization: organization} do
      conn = conn |> log_in_organization(organization) |> delete(Routes.organization_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :organization_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the organization is not logged in", %{conn: conn} do
      conn = delete(conn, Routes.organization_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :organization_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
