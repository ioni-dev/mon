defmodule MonWeb.ClientSessionControllerTest do
  use MonWeb.ConnCase, async: true

  import Mon.AccountsFixtures

  setup do
    %{client: client_fixture()}
  end

  describe "GET /clients/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, Routes.client_session_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Log in</a>"
      assert response =~ "Register</a>"
    end

    test "redirects if already logged in", %{conn: conn, client: client} do
      conn = conn |> log_in_client(client) |> get(Routes.client_session_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /clients/log_in" do
    test "logs the client in", %{conn: conn, client: client} do
      conn =
        post(conn, Routes.client_session_path(conn, :create), %{
          "client" => %{"email" => client.email, "password" => valid_client_password()}
        })

      assert get_session(conn, :client_token)
      assert redirected_to(conn) =~ "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ client.email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "logs the client in with remember me", %{conn: conn, client: client} do
      conn =
        post(conn, Routes.client_session_path(conn, :create), %{
          "client" => %{
            "email" => client.email,
            "password" => valid_client_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["client_remember_me"]
      assert redirected_to(conn) =~ "/"
    end

    test "emits error message with invalid credentials", %{conn: conn, client: client} do
      conn =
        post(conn, Routes.client_session_path(conn, :create), %{
          "client" => %{"email" => client.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /clients/log_out" do
    test "logs the client out", %{conn: conn, client: client} do
      conn = conn |> log_in_client(client) |> delete(Routes.client_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :client_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the client is not logged in", %{conn: conn} do
      conn = delete(conn, Routes.client_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :client_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
