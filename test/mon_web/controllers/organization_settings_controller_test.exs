defmodule MonWeb.OrganizationSettingsControllerTest do
  use MonWeb.ConnCase, async: true

  alias Mon.Accounts
  import Mon.AccountsFixtures

  setup :register_and_log_in_organization

  describe "GET /organizations/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, Routes.organization_settings_path(conn, :edit))
      response = html_response(conn, 200)
      assert response =~ "<h1>Settings</h1>"
    end

    test "redirects if organization is not logged in" do
      conn = build_conn()
      conn = get(conn, Routes.organization_settings_path(conn, :edit))
      assert redirected_to(conn) == Routes.organization_session_path(conn, :new)
    end
  end

  describe "PUT /organizations/settings/update_password" do
    test "updates the organization password and resets tokens", %{conn: conn, organization: organization} do
      new_password_conn =
        put(conn, Routes.organization_settings_path(conn, :update_password), %{
          "current_password" => valid_organization_password(),
          "organization" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == Routes.organization_settings_path(conn, :edit)
      assert get_session(new_password_conn, :organization_token) != get_session(conn, :organization_token)
      assert get_flash(new_password_conn, :info) =~ "Password updated successfully"
      assert Accounts.get_organization_by_email_and_password(organization.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, Routes.organization_settings_path(conn, :update_password), %{
          "current_password" => "invalid",
          "organization" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(old_password_conn, 200)
      assert response =~ "<h1>Settings</h1>"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"
      assert response =~ "is not valid"

      assert get_session(old_password_conn, :organization_token) == get_session(conn, :organization_token)
    end
  end

  describe "PUT /organizations/settings/update_email" do
    @tag :capture_log
    test "updates the organization email", %{conn: conn, organization: organization} do
      conn =
        put(conn, Routes.organization_settings_path(conn, :update_email), %{
          "current_password" => valid_organization_password(),
          "organization" => %{"email" => unique_organization_email()}
        })

      assert redirected_to(conn) == Routes.organization_settings_path(conn, :edit)
      assert get_flash(conn, :info) =~ "A link to confirm your email"
      assert Accounts.get_organization_by_email(organization.email)
    end

    test "does not update email on invalid data", %{conn: conn} do
      conn =
        put(conn, Routes.organization_settings_path(conn, :update_email), %{
          "current_password" => "invalid",
          "organization" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Settings</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "is not valid"
    end
  end

  describe "GET /organizations/settings/confirm_email/:token" do
    setup %{organization: organization} do
      email = unique_organization_email()

      token =
        extract_organization_token(fn url ->
          Accounts.deliver_update_email_instructions(%{organization | email: email}, organization.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the organization email once", %{conn: conn, organization: organization, token: token, email: email} do
      conn = get(conn, Routes.organization_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.organization_settings_path(conn, :edit)
      assert get_flash(conn, :info) =~ "Email changed successfully"
      refute Accounts.get_organization_by_email(organization.email)
      assert Accounts.get_organization_by_email(email)

      conn = get(conn, Routes.organization_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.organization_settings_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, organization: organization} do
      conn = get(conn, Routes.organization_settings_path(conn, :confirm_email, "oops"))
      assert redirected_to(conn) == Routes.organization_settings_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
      assert Accounts.get_organization_by_email(organization.email)
    end

    test "redirects if organization is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, Routes.organization_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.organization_session_path(conn, :new)
    end
  end
end
