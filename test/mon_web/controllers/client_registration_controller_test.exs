defmodule MonWeb.ClientRegistrationControllerTest do
  use MonWeb.ConnCase, async: true

  import Mon.AccountsFixtures

  describe "GET /clients/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, Routes.client_registration_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "Log in</a>"
      assert response =~ "Register</a>"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_client(client_fixture()) |> get(Routes.client_registration_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /clients/register" do
    @tag :capture_log
    test "creates account and logs the client in", %{conn: conn} do
      email = unique_client_email()

      conn =
        post(conn, Routes.client_registration_path(conn, :create), %{
          "client" => %{"email" => email, "password" => valid_client_password()}
        })

      assert get_session(conn, :client_token)
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
        post(conn, Routes.client_registration_path(conn, :create), %{
          "client" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
