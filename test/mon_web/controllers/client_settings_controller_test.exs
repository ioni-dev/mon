defmodule MonWeb.ClientSettingsControllerTest do
  use MonWeb.ConnCase, async: true

  alias Mon.Accounts
  import Mon.AccountsFixtures

  setup :register_and_log_in_client

  describe "GET /clients/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, Routes.client_settings_path(conn, :edit))
      response = html_response(conn, 200)
      assert response =~ "<h1>Settings</h1>"
    end

    test "redirects if client is not logged in" do
      conn = build_conn()
      conn = get(conn, Routes.client_settings_path(conn, :edit))
      assert redirected_to(conn) == Routes.client_session_path(conn, :new)
    end
  end

  describe "PUT /clients/settings/update_password" do
    test "updates the client password and resets tokens", %{conn: conn, client: client} do
      new_password_conn =
        put(conn, Routes.client_settings_path(conn, :update_password), %{
          "current_password" => valid_client_password(),
          "client" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == Routes.client_settings_path(conn, :edit)
      assert get_session(new_password_conn, :client_token) != get_session(conn, :client_token)
      assert get_flash(new_password_conn, :info) =~ "Password updated successfully"
      assert Accounts.get_client_by_email_and_password(client.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, Routes.client_settings_path(conn, :update_password), %{
          "current_password" => "invalid",
          "client" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(old_password_conn, 200)
      assert response =~ "<h1>Settings</h1>"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"
      assert response =~ "is not valid"

      assert get_session(old_password_conn, :client_token) == get_session(conn, :client_token)
    end
  end

  describe "PUT /clients/settings/update_email" do
    @tag :capture_log
    test "updates the client email", %{conn: conn, client: client} do
      conn =
        put(conn, Routes.client_settings_path(conn, :update_email), %{
          "current_password" => valid_client_password(),
          "client" => %{"email" => unique_client_email()}
        })

      assert redirected_to(conn) == Routes.client_settings_path(conn, :edit)
      assert get_flash(conn, :info) =~ "A link to confirm your email"
      assert Accounts.get_client_by_email(client.email)
    end

    test "does not update email on invalid data", %{conn: conn} do
      conn =
        put(conn, Routes.client_settings_path(conn, :update_email), %{
          "current_password" => "invalid",
          "client" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Settings</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "is not valid"
    end
  end

  describe "GET /clients/settings/confirm_email/:token" do
    setup %{client: client} do
      email = unique_client_email()

      token =
        extract_client_token(fn url ->
          Accounts.deliver_update_email_instructions(%{client | email: email}, client.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the client email once", %{conn: conn, client: client, token: token, email: email} do
      conn = get(conn, Routes.client_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.client_settings_path(conn, :edit)
      assert get_flash(conn, :info) =~ "Email changed successfully"
      refute Accounts.get_client_by_email(client.email)
      assert Accounts.get_client_by_email(email)

      conn = get(conn, Routes.client_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.client_settings_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, client: client} do
      conn = get(conn, Routes.client_settings_path(conn, :confirm_email, "oops"))
      assert redirected_to(conn) == Routes.client_settings_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
      assert Accounts.get_client_by_email(client.email)
    end

    test "redirects if client is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, Routes.client_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.client_session_path(conn, :new)
    end
  end
end
