defmodule MonWeb.ClientResetPasswordControllerTest do
  use MonWeb.ConnCase, async: true

  alias Mon.Accounts
  alias Mon.Repo
  import Mon.AccountsFixtures

  setup do
    %{client: client_fixture()}
  end

  describe "GET /clients/reset_password" do
    test "renders the reset password page", %{conn: conn} do
      conn = get(conn, Routes.client_reset_password_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Forgot your password?</h1>"
    end
  end

  describe "POST /clients/reset_password" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, client: client} do
      conn =
        post(conn, Routes.client_reset_password_path(conn, :create), %{
          "client" => %{"email" => client.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Accounts.ClientToken, client_id: client.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.client_reset_password_path(conn, :create), %{
          "client" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.ClientToken) == []
    end
  end

  describe "GET /clients/reset_password/:token" do
    setup %{client: client} do
      token =
        extract_client_token(fn url ->
          Accounts.deliver_client_reset_password_instructions(client, url)
        end)

      %{token: token}
    end

    test "renders reset password", %{conn: conn, token: token} do
      conn = get(conn, Routes.client_reset_password_path(conn, :edit, token))
      assert html_response(conn, 200) =~ "<h1>Reset password</h1>"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      conn = get(conn, Routes.client_reset_password_path(conn, :edit, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end

  describe "PUT /clients/reset_password/:token" do
    setup %{client: client} do
      token =
        extract_client_token(fn url ->
          Accounts.deliver_client_reset_password_instructions(client, url)
        end)

      %{token: token}
    end

    test "resets password once", %{conn: conn, client: client, token: token} do
      conn =
        put(conn, Routes.client_reset_password_path(conn, :update, token), %{
          "client" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == Routes.client_session_path(conn, :new)
      refute get_session(conn, :client_token)
      assert get_flash(conn, :info) =~ "Password reset successfully"
      assert Accounts.get_client_by_email_and_password(client.email, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, Routes.client_reset_password_path(conn, :update, token), %{
          "client" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Reset password</h1>"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"
    end

    test "does not reset password with invalid token", %{conn: conn} do
      conn = put(conn, Routes.client_reset_password_path(conn, :update, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end
end
