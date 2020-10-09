defmodule MonWeb.OrganizationConfirmationControllerTest do
  use MonWeb.ConnCase, async: true

  alias Mon.Accounts
  alias Mon.Repo
  import Mon.AccountsFixtures

  setup do
    %{organization: organization_fixture()}
  end

  describe "GET /organizations/confirm" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.organization_confirmation_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /organizations/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, organization: organization} do
      conn =
        post(conn, Routes.organization_confirmation_path(conn, :create), %{
          "organization" => %{"email" => organization.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Accounts.OrganizationToken, organization_id: organization.id).context == "confirm"
    end

    test "does not send confirmation token if account is confirmed", %{conn: conn, organization: organization} do
      Repo.update!(Accounts.Organization.confirm_changeset(organization))

      conn =
        post(conn, Routes.organization_confirmation_path(conn, :create), %{
          "organization" => %{"email" => organization.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(Accounts.OrganizationToken, organization_id: organization.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.organization_confirmation_path(conn, :create), %{
          "organization" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.OrganizationToken) == []
    end
  end

  describe "GET /organizations/confirm/:token" do
    test "confirms the given token once", %{conn: conn, organization: organization} do
      token =
        extract_organization_token(fn url ->
          Accounts.deliver_organization_confirmation_instructions(organization, url)
        end)

      conn = get(conn, Routes.organization_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "Account confirmed successfully"
      assert Accounts.get_organization!(organization.id).confirmed_at
      refute get_session(conn, :organization_token)
      assert Repo.all(Accounts.OrganizationToken) == []

      conn = get(conn, Routes.organization_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Confirmation link is invalid or it has expired"
    end

    test "does not confirm email with invalid token", %{conn: conn, organization: organization} do
      conn = get(conn, Routes.organization_confirmation_path(conn, :confirm, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Confirmation link is invalid or it has expired"
      refute Accounts.get_organization!(organization.id).confirmed_at
    end
  end
end
