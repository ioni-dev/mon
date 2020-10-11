defmodule MonWeb.DriverResetPasswordControllerTest do
  use MonWeb.ConnCase, async: true

  alias Mon.Accounts
  alias Mon.Repo
  import Mon.AccountsFixtures

  setup do
    %{driver: driver_fixture()}
  end

  describe "GET /drivers/reset_password" do
    test "renders the reset password page", %{conn: conn} do
      conn = get(conn, Routes.driver_reset_password_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Forgot your password?</h1>"
    end
  end

  describe "POST /drivers/reset_password" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, driver: driver} do
      conn =
        post(conn, Routes.driver_reset_password_path(conn, :create), %{
          "driver" => %{"email" => driver.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Accounts.DriverToken, driver_id: driver.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.driver_reset_password_path(conn, :create), %{
          "driver" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.DriverToken) == []
    end
  end

  describe "GET /drivers/reset_password/:token" do
    setup %{driver: driver} do
      token =
        extract_driver_token(fn url ->
          Accounts.deliver_driver_reset_password_instructions(driver, url)
        end)

      %{token: token}
    end

    test "renders reset password", %{conn: conn, token: token} do
      conn = get(conn, Routes.driver_reset_password_path(conn, :edit, token))
      assert html_response(conn, 200) =~ "<h1>Reset password</h1>"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      conn = get(conn, Routes.driver_reset_password_path(conn, :edit, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end

  describe "PUT /drivers/reset_password/:token" do
    setup %{driver: driver} do
      token =
        extract_driver_token(fn url ->
          Accounts.deliver_driver_reset_password_instructions(driver, url)
        end)

      %{token: token}
    end

    test "resets password once", %{conn: conn, driver: driver, token: token} do
      conn =
        put(conn, Routes.driver_reset_password_path(conn, :update, token), %{
          "driver" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == Routes.driver_session_path(conn, :new)
      refute get_session(conn, :driver_token)
      assert get_flash(conn, :info) =~ "Password reset successfully"
      assert Accounts.get_driver_by_email_and_password(driver.email, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, Routes.driver_reset_password_path(conn, :update, token), %{
          "driver" => %{
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
      conn = put(conn, Routes.driver_reset_password_path(conn, :update, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end
end
