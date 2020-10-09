defmodule MonWeb.ClientConfirmationControllerTest do
  use MonWeb.ConnCase, async: true

  alias Mon.Accounts
  alias Mon.Repo
  import Mon.AccountsFixtures

  setup do
    %{client: client_fixture()}
  end

  describe "GET /clients/confirm" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.client_confirmation_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /clients/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, client: client} do
      conn =
        post(conn, Routes.client_confirmation_path(conn, :create), %{
          "client" => %{"email" => client.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Accounts.ClientToken, client_id: client.id).context == "confirm"
    end

    test "does not send confirmation token if account is confirmed", %{conn: conn, client: client} do
      Repo.update!(Accounts.Client.confirm_changeset(client))

      conn =
        post(conn, Routes.client_confirmation_path(conn, :create), %{
          "client" => %{"email" => client.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(Accounts.ClientToken, client_id: client.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.client_confirmation_path(conn, :create), %{
          "client" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.ClientToken) == []
    end
  end

  describe "GET /clients/confirm/:token" do
    test "confirms the given token once", %{conn: conn, client: client} do
      token =
        extract_client_token(fn url ->
          Accounts.deliver_client_confirmation_instructions(client, url)
        end)

      conn = get(conn, Routes.client_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "Account confirmed successfully"
      assert Accounts.get_client!(client.id).confirmed_at
      refute get_session(conn, :client_token)
      assert Repo.all(Accounts.ClientToken) == []

      conn = get(conn, Routes.client_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Confirmation link is invalid or it has expired"
    end

    test "does not confirm email with invalid token", %{conn: conn, client: client} do
      conn = get(conn, Routes.client_confirmation_path(conn, :confirm, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Confirmation link is invalid or it has expired"
      refute Accounts.get_client!(client.id).confirmed_at
    end
  end
end
