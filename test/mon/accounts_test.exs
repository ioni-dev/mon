defmodule Mon.AccountsTest do
  use Mon.DataCase

  alias Mon.Accounts
  import Mon.AccountsFixtures
  alias Mon.Accounts.{Driver, DriverToken}

  describe "get_driver_by_email/1" do
    test "does not return the driver if the email does not exist" do
      refute Accounts.get_driver_by_email("unknown@example.com")
    end

    test "returns the driver if the email exists" do
      %{id: id} = driver = driver_fixture()
      assert %Driver{id: ^id} = Accounts.get_driver_by_email(driver.email)
    end
  end

  describe "get_driver_by_email_and_password/2" do
    test "does not return the driver if the email does not exist" do
      refute Accounts.get_driver_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the driver if the password is not valid" do
      driver = driver_fixture()
      refute Accounts.get_driver_by_email_and_password(driver.email, "invalid")
    end

    test "returns the driver if the email and password are valid" do
      %{id: id} = driver = driver_fixture()

      assert %Driver{id: ^id} =
               Accounts.get_driver_by_email_and_password(driver.email, valid_driver_password())
    end
  end

  describe "get_driver!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_driver!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the driver with the given id" do
      %{id: id} = driver = driver_fixture()
      assert %Driver{id: ^id} = Accounts.get_driver!(driver.id)
    end
  end

  describe "register_driver/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_driver(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_driver(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_driver(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = driver_fixture()
      {:error, changeset} = Accounts.register_driver(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_driver(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers drivers with a hashed password" do
      email = unique_driver_email()
      {:ok, driver} = Accounts.register_driver(%{email: email, password: valid_driver_password()})
      assert driver.email == email
      assert is_binary(driver.hashed_password)
      assert is_nil(driver.confirmed_at)
      assert is_nil(driver.password)
    end
  end

  describe "change_driver_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_driver_registration(%Driver{})
      assert changeset.required == [:password, :email]
    end
  end

  describe "change_driver_email/2" do
    test "returns a driver changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_driver_email(%Driver{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_driver_email/3" do
    setup do
      %{driver: driver_fixture()}
    end

    test "requires email to change", %{driver: driver} do
      {:error, changeset} = Accounts.apply_driver_email(driver, valid_driver_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{driver: driver} do
      {:error, changeset} =
        Accounts.apply_driver_email(driver, valid_driver_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{driver: driver} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_driver_email(driver, valid_driver_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{driver: driver} do
      %{email: email} = driver_fixture()

      {:error, changeset} =
        Accounts.apply_driver_email(driver, valid_driver_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{driver: driver} do
      {:error, changeset} =
        Accounts.apply_driver_email(driver, "invalid", %{email: unique_driver_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{driver: driver} do
      email = unique_driver_email()
      {:ok, driver} = Accounts.apply_driver_email(driver, valid_driver_password(), %{email: email})
      assert driver.email == email
      assert Accounts.get_driver!(driver.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{driver: driver_fixture()}
    end

    test "sends token through notification", %{driver: driver} do
      token =
        extract_driver_token(fn url ->
          Accounts.deliver_update_email_instructions(driver, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert driver_token = Repo.get_by(DriverToken, token: :crypto.hash(:sha256, token))
      assert driver_token.driver_id == driver.id
      assert driver_token.sent_to == driver.email
      assert driver_token.context == "change:current@example.com"
    end
  end

  describe "update_driver_email/2" do
    setup do
      driver = driver_fixture()
      email = unique_driver_email()

      token =
        extract_driver_token(fn url ->
          Accounts.deliver_update_email_instructions(%{driver | email: email}, driver.email, url)
        end)

      %{driver: driver, token: token, email: email}
    end

    test "updates the email with a valid token", %{driver: driver, token: token, email: email} do
      assert Accounts.update_driver_email(driver, token) == :ok
      changed_driver = Repo.get!(Driver, driver.id)
      assert changed_driver.email != driver.email
      assert changed_driver.email == email
      assert changed_driver.confirmed_at
      assert changed_driver.confirmed_at != driver.confirmed_at
      refute Repo.get_by(DriverToken, driver_id: driver.id)
    end

    test "does not update email with invalid token", %{driver: driver} do
      assert Accounts.update_driver_email(driver, "oops") == :error
      assert Repo.get!(Driver, driver.id).email == driver.email
      assert Repo.get_by(DriverToken, driver_id: driver.id)
    end

    test "does not update email if driver email changed", %{driver: driver, token: token} do
      assert Accounts.update_driver_email(%{driver | email: "current@example.com"}, token) == :error
      assert Repo.get!(Driver, driver.id).email == driver.email
      assert Repo.get_by(DriverToken, driver_id: driver.id)
    end

    test "does not update email if token expired", %{driver: driver, token: token} do
      {1, nil} = Repo.update_all(DriverToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_driver_email(driver, token) == :error
      assert Repo.get!(Driver, driver.id).email == driver.email
      assert Repo.get_by(DriverToken, driver_id: driver.id)
    end
  end

  describe "change_driver_password/2" do
    test "returns a driver changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_driver_password(%Driver{})
      assert changeset.required == [:password]
    end
  end

  describe "update_driver_password/3" do
    setup do
      %{driver: driver_fixture()}
    end

    test "validates password", %{driver: driver} do
      {:error, changeset} =
        Accounts.update_driver_password(driver, valid_driver_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{driver: driver} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_driver_password(driver, valid_driver_password(), %{password: too_long})

      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{driver: driver} do
      {:error, changeset} =
        Accounts.update_driver_password(driver, "invalid", %{password: valid_driver_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{driver: driver} do
      {:ok, driver} =
        Accounts.update_driver_password(driver, valid_driver_password(), %{
          password: "new valid password"
        })

      assert is_nil(driver.password)
      assert Accounts.get_driver_by_email_and_password(driver.email, "new valid password")
    end

    test "deletes all tokens for the given driver", %{driver: driver} do
      _ = Accounts.generate_driver_session_token(driver)

      {:ok, _} =
        Accounts.update_driver_password(driver, valid_driver_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(DriverToken, driver_id: driver.id)
    end
  end

  describe "generate_driver_session_token/1" do
    setup do
      %{driver: driver_fixture()}
    end

    test "generates a token", %{driver: driver} do
      token = Accounts.generate_driver_session_token(driver)
      assert driver_token = Repo.get_by(DriverToken, token: token)
      assert driver_token.context == "session"

      # Creating the same token for another driver should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%DriverToken{
          token: driver_token.token,
          driver_id: driver_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_driver_by_session_token/1" do
    setup do
      driver = driver_fixture()
      token = Accounts.generate_driver_session_token(driver)
      %{driver: driver, token: token}
    end

    test "returns driver by token", %{driver: driver, token: token} do
      assert session_driver = Accounts.get_driver_by_session_token(token)
      assert session_driver.id == driver.id
    end

    test "does not return driver for invalid token" do
      refute Accounts.get_driver_by_session_token("oops")
    end

    test "does not return driver for expired token", %{token: token} do
      {1, nil} = Repo.update_all(DriverToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_driver_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      driver = driver_fixture()
      token = Accounts.generate_driver_session_token(driver)
      assert Accounts.delete_session_token(token) == :ok
      refute Accounts.get_driver_by_session_token(token)
    end
  end

  describe "deliver_driver_confirmation_instructions/2" do
    setup do
      %{driver: driver_fixture()}
    end

    test "sends token through notification", %{driver: driver} do
      token =
        extract_driver_token(fn url ->
          Accounts.deliver_driver_confirmation_instructions(driver, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert driver_token = Repo.get_by(DriverToken, token: :crypto.hash(:sha256, token))
      assert driver_token.driver_id == driver.id
      assert driver_token.sent_to == driver.email
      assert driver_token.context == "confirm"
    end
  end

  describe "confirm_driver/2" do
    setup do
      driver = driver_fixture()

      token =
        extract_driver_token(fn url ->
          Accounts.deliver_driver_confirmation_instructions(driver, url)
        end)

      %{driver: driver, token: token}
    end

    test "confirms the email with a valid token", %{driver: driver, token: token} do
      assert {:ok, confirmed_driver} = Accounts.confirm_driver(token)
      assert confirmed_driver.confirmed_at
      assert confirmed_driver.confirmed_at != driver.confirmed_at
      assert Repo.get!(Driver, driver.id).confirmed_at
      refute Repo.get_by(DriverToken, driver_id: driver.id)
    end

    test "does not confirm with invalid token", %{driver: driver} do
      assert Accounts.confirm_driver("oops") == :error
      refute Repo.get!(Driver, driver.id).confirmed_at
      assert Repo.get_by(DriverToken, driver_id: driver.id)
    end

    test "does not confirm email if token expired", %{driver: driver, token: token} do
      {1, nil} = Repo.update_all(DriverToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_driver(token) == :error
      refute Repo.get!(Driver, driver.id).confirmed_at
      assert Repo.get_by(DriverToken, driver_id: driver.id)
    end
  end

  describe "deliver_driver_reset_password_instructions/2" do
    setup do
      %{driver: driver_fixture()}
    end

    test "sends token through notification", %{driver: driver} do
      token =
        extract_driver_token(fn url ->
          Accounts.deliver_driver_reset_password_instructions(driver, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert driver_token = Repo.get_by(DriverToken, token: :crypto.hash(:sha256, token))
      assert driver_token.driver_id == driver.id
      assert driver_token.sent_to == driver.email
      assert driver_token.context == "reset_password"
    end
  end

  describe "get_driver_by_reset_password_token/1" do
    setup do
      driver = driver_fixture()

      token =
        extract_driver_token(fn url ->
          Accounts.deliver_driver_reset_password_instructions(driver, url)
        end)

      %{driver: driver, token: token}
    end

    test "returns the driver with valid token", %{driver: %{id: id}, token: token} do
      assert %Driver{id: ^id} = Accounts.get_driver_by_reset_password_token(token)
      assert Repo.get_by(DriverToken, driver_id: id)
    end

    test "does not return the driver with invalid token", %{driver: driver} do
      refute Accounts.get_driver_by_reset_password_token("oops")
      assert Repo.get_by(DriverToken, driver_id: driver.id)
    end

    test "does not return the driver if token expired", %{driver: driver, token: token} do
      {1, nil} = Repo.update_all(DriverToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_driver_by_reset_password_token(token)
      assert Repo.get_by(DriverToken, driver_id: driver.id)
    end
  end

  describe "reset_driver_password/2" do
    setup do
      %{driver: driver_fixture()}
    end

    test "validates password", %{driver: driver} do
      {:error, changeset} =
        Accounts.reset_driver_password(driver, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{driver: driver} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_driver_password(driver, %{password: too_long})
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{driver: driver} do
      {:ok, updated_driver} = Accounts.reset_driver_password(driver, %{password: "new valid password"})
      assert is_nil(updated_driver.password)
      assert Accounts.get_driver_by_email_and_password(driver.email, "new valid password")
    end

    test "deletes all tokens for the given driver", %{driver: driver} do
      _ = Accounts.generate_driver_session_token(driver)
      {:ok, _} = Accounts.reset_driver_password(driver, %{password: "new valid password"})
      refute Repo.get_by(DriverToken, driver_id: driver.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%Driver{password: "123456"}) =~ "password: \"123456\""
    end
  end
  import Mon.AccountsFixtures
  alias Mon.Accounts.{Client, ClientToken}

  describe "get_client_by_email/1" do
    test "does not return the client if the email does not exist" do
      refute Accounts.get_client_by_email("unknown@example.com")
    end

    test "returns the client if the email exists" do
      %{id: id} = client = client_fixture()
      assert %Client{id: ^id} = Accounts.get_client_by_email(client.email)
    end
  end

  describe "get_client_by_email_and_password/2" do
    test "does not return the client if the email does not exist" do
      refute Accounts.get_client_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the client if the password is not valid" do
      client = client_fixture()
      refute Accounts.get_client_by_email_and_password(client.email, "invalid")
    end

    test "returns the client if the email and password are valid" do
      %{id: id} = client = client_fixture()

      assert %Client{id: ^id} =
               Accounts.get_client_by_email_and_password(client.email, valid_client_password())
    end
  end

  describe "get_client!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_client!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the client with the given id" do
      %{id: id} = client = client_fixture()
      assert %Client{id: ^id} = Accounts.get_client!(client.id)
    end
  end

  describe "register_client/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_client(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_client(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_client(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = client_fixture()
      {:error, changeset} = Accounts.register_client(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_client(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers clients with a hashed password" do
      email = unique_client_email()
      {:ok, client} = Accounts.register_client(%{email: email, password: valid_client_password()})
      assert client.email == email
      assert is_binary(client.hashed_password)
      assert is_nil(client.confirmed_at)
      assert is_nil(client.password)
    end
  end

  describe "change_client_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_client_registration(%Client{})
      assert changeset.required == [:password, :email]
    end
  end

  describe "change_client_email/2" do
    test "returns a client changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_client_email(%Client{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_client_email/3" do
    setup do
      %{client: client_fixture()}
    end

    test "requires email to change", %{client: client} do
      {:error, changeset} = Accounts.apply_client_email(client, valid_client_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{client: client} do
      {:error, changeset} =
        Accounts.apply_client_email(client, valid_client_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{client: client} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_client_email(client, valid_client_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{client: client} do
      %{email: email} = client_fixture()

      {:error, changeset} =
        Accounts.apply_client_email(client, valid_client_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{client: client} do
      {:error, changeset} =
        Accounts.apply_client_email(client, "invalid", %{email: unique_client_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{client: client} do
      email = unique_client_email()
      {:ok, client} = Accounts.apply_client_email(client, valid_client_password(), %{email: email})
      assert client.email == email
      assert Accounts.get_client!(client.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{client: client_fixture()}
    end

    test "sends token through notification", %{client: client} do
      token =
        extract_client_token(fn url ->
          Accounts.deliver_update_email_instructions(client, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert client_token = Repo.get_by(ClientToken, token: :crypto.hash(:sha256, token))
      assert client_token.client_id == client.id
      assert client_token.sent_to == client.email
      assert client_token.context == "change:current@example.com"
    end
  end

  describe "update_client_email/2" do
    setup do
      client = client_fixture()
      email = unique_client_email()

      token =
        extract_client_token(fn url ->
          Accounts.deliver_update_email_instructions(%{client | email: email}, client.email, url)
        end)

      %{client: client, token: token, email: email}
    end

    test "updates the email with a valid token", %{client: client, token: token, email: email} do
      assert Accounts.update_client_email(client, token) == :ok
      changed_client = Repo.get!(Client, client.id)
      assert changed_client.email != client.email
      assert changed_client.email == email
      assert changed_client.confirmed_at
      assert changed_client.confirmed_at != client.confirmed_at
      refute Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not update email with invalid token", %{client: client} do
      assert Accounts.update_client_email(client, "oops") == :error
      assert Repo.get!(Client, client.id).email == client.email
      assert Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not update email if client email changed", %{client: client, token: token} do
      assert Accounts.update_client_email(%{client | email: "current@example.com"}, token) == :error
      assert Repo.get!(Client, client.id).email == client.email
      assert Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not update email if token expired", %{client: client, token: token} do
      {1, nil} = Repo.update_all(ClientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_client_email(client, token) == :error
      assert Repo.get!(Client, client.id).email == client.email
      assert Repo.get_by(ClientToken, client_id: client.id)
    end
  end

  describe "change_client_password/2" do
    test "returns a client changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_client_password(%Client{})
      assert changeset.required == [:password]
    end
  end

  describe "update_client_password/3" do
    setup do
      %{client: client_fixture()}
    end

    test "validates password", %{client: client} do
      {:error, changeset} =
        Accounts.update_client_password(client, valid_client_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{client: client} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_client_password(client, valid_client_password(), %{password: too_long})

      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{client: client} do
      {:error, changeset} =
        Accounts.update_client_password(client, "invalid", %{password: valid_client_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{client: client} do
      {:ok, client} =
        Accounts.update_client_password(client, valid_client_password(), %{
          password: "new valid password"
        })

      assert is_nil(client.password)
      assert Accounts.get_client_by_email_and_password(client.email, "new valid password")
    end

    test "deletes all tokens for the given client", %{client: client} do
      _ = Accounts.generate_client_session_token(client)

      {:ok, _} =
        Accounts.update_client_password(client, valid_client_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(ClientToken, client_id: client.id)
    end
  end

  describe "generate_client_session_token/1" do
    setup do
      %{client: client_fixture()}
    end

    test "generates a token", %{client: client} do
      token = Accounts.generate_client_session_token(client)
      assert client_token = Repo.get_by(ClientToken, token: token)
      assert client_token.context == "session"

      # Creating the same token for another client should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%ClientToken{
          token: client_token.token,
          client_id: client_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_client_by_session_token/1" do
    setup do
      client = client_fixture()
      token = Accounts.generate_client_session_token(client)
      %{client: client, token: token}
    end

    test "returns client by token", %{client: client, token: token} do
      assert session_client = Accounts.get_client_by_session_token(token)
      assert session_client.id == client.id
    end

    test "does not return client for invalid token" do
      refute Accounts.get_client_by_session_token("oops")
    end

    test "does not return client for expired token", %{token: token} do
      {1, nil} = Repo.update_all(ClientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_client_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      client = client_fixture()
      token = Accounts.generate_client_session_token(client)
      assert Accounts.delete_session_token(token) == :ok
      refute Accounts.get_client_by_session_token(token)
    end
  end

  describe "deliver_client_confirmation_instructions/2" do
    setup do
      %{client: client_fixture()}
    end

    test "sends token through notification", %{client: client} do
      token =
        extract_client_token(fn url ->
          Accounts.deliver_client_confirmation_instructions(client, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert client_token = Repo.get_by(ClientToken, token: :crypto.hash(:sha256, token))
      assert client_token.client_id == client.id
      assert client_token.sent_to == client.email
      assert client_token.context == "confirm"
    end
  end

  describe "confirm_client/2" do
    setup do
      client = client_fixture()

      token =
        extract_client_token(fn url ->
          Accounts.deliver_client_confirmation_instructions(client, url)
        end)

      %{client: client, token: token}
    end

    test "confirms the email with a valid token", %{client: client, token: token} do
      assert {:ok, confirmed_client} = Accounts.confirm_client(token)
      assert confirmed_client.confirmed_at
      assert confirmed_client.confirmed_at != client.confirmed_at
      assert Repo.get!(Client, client.id).confirmed_at
      refute Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not confirm with invalid token", %{client: client} do
      assert Accounts.confirm_client("oops") == :error
      refute Repo.get!(Client, client.id).confirmed_at
      assert Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not confirm email if token expired", %{client: client, token: token} do
      {1, nil} = Repo.update_all(ClientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_client(token) == :error
      refute Repo.get!(Client, client.id).confirmed_at
      assert Repo.get_by(ClientToken, client_id: client.id)
    end
  end

  describe "deliver_client_reset_password_instructions/2" do
    setup do
      %{client: client_fixture()}
    end

    test "sends token through notification", %{client: client} do
      token =
        extract_client_token(fn url ->
          Accounts.deliver_client_reset_password_instructions(client, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert client_token = Repo.get_by(ClientToken, token: :crypto.hash(:sha256, token))
      assert client_token.client_id == client.id
      assert client_token.sent_to == client.email
      assert client_token.context == "reset_password"
    end
  end

  describe "get_client_by_reset_password_token/1" do
    setup do
      client = client_fixture()

      token =
        extract_client_token(fn url ->
          Accounts.deliver_client_reset_password_instructions(client, url)
        end)

      %{client: client, token: token}
    end

    test "returns the client with valid token", %{client: %{id: id}, token: token} do
      assert %Client{id: ^id} = Accounts.get_client_by_reset_password_token(token)
      assert Repo.get_by(ClientToken, client_id: id)
    end

    test "does not return the client with invalid token", %{client: client} do
      refute Accounts.get_client_by_reset_password_token("oops")
      assert Repo.get_by(ClientToken, client_id: client.id)
    end

    test "does not return the client if token expired", %{client: client, token: token} do
      {1, nil} = Repo.update_all(ClientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_client_by_reset_password_token(token)
      assert Repo.get_by(ClientToken, client_id: client.id)
    end
  end

  describe "reset_client_password/2" do
    setup do
      %{client: client_fixture()}
    end

    test "validates password", %{client: client} do
      {:error, changeset} =
        Accounts.reset_client_password(client, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{client: client} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_client_password(client, %{password: too_long})
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{client: client} do
      {:ok, updated_client} = Accounts.reset_client_password(client, %{password: "new valid password"})
      assert is_nil(updated_client.password)
      assert Accounts.get_client_by_email_and_password(client.email, "new valid password")
    end

    test "deletes all tokens for the given client", %{client: client} do
      _ = Accounts.generate_client_session_token(client)
      {:ok, _} = Accounts.reset_client_password(client, %{password: "new valid password"})
      refute Repo.get_by(ClientToken, client_id: client.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%Client{password: "123456"}) =~ "password: \"123456\""
    end
  end
  import Mon.AccountsFixtures
  alias Mon.Accounts.{Organization, OrganizationToken}

  describe "get_organization_by_email/1" do
    test "does not return the organization if the email does not exist" do
      refute Accounts.get_organization_by_email("unknown@example.com")
    end

    test "returns the organization if the email exists" do
      %{id: id} = organization = organization_fixture()
      assert %Organization{id: ^id} = Accounts.get_organization_by_email(organization.email)
    end
  end

  describe "get_organization_by_email_and_password/2" do
    test "does not return the organization if the email does not exist" do
      refute Accounts.get_organization_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the organization if the password is not valid" do
      organization = organization_fixture()
      refute Accounts.get_organization_by_email_and_password(organization.email, "invalid")
    end

    test "returns the organization if the email and password are valid" do
      %{id: id} = organization = organization_fixture()

      assert %Organization{id: ^id} =
               Accounts.get_organization_by_email_and_password(organization.email, valid_organization_password())
    end
  end

  describe "get_organization!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_organization!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the organization with the given id" do
      %{id: id} = organization = organization_fixture()
      assert %Organization{id: ^id} = Accounts.get_organization!(organization.id)
    end
  end

  describe "register_organization/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_organization(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_organization(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_organization(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = organization_fixture()
      {:error, changeset} = Accounts.register_organization(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_organization(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers organizations with a hashed password" do
      email = unique_organization_email()
      {:ok, organization} = Accounts.register_organization(%{email: email, password: valid_organization_password()})
      assert organization.email == email
      assert is_binary(organization.hashed_password)
      assert is_nil(organization.confirmed_at)
      assert is_nil(organization.password)
    end
  end

  describe "change_organization_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_organization_registration(%Organization{})
      assert changeset.required == [:password, :email]
    end
  end

  describe "change_organization_email/2" do
    test "returns a organization changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_organization_email(%Organization{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_organization_email/3" do
    setup do
      %{organization: organization_fixture()}
    end

    test "requires email to change", %{organization: organization} do
      {:error, changeset} = Accounts.apply_organization_email(organization, valid_organization_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{organization: organization} do
      {:error, changeset} =
        Accounts.apply_organization_email(organization, valid_organization_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{organization: organization} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_organization_email(organization, valid_organization_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{organization: organization} do
      %{email: email} = organization_fixture()

      {:error, changeset} =
        Accounts.apply_organization_email(organization, valid_organization_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{organization: organization} do
      {:error, changeset} =
        Accounts.apply_organization_email(organization, "invalid", %{email: unique_organization_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{organization: organization} do
      email = unique_organization_email()
      {:ok, organization} = Accounts.apply_organization_email(organization, valid_organization_password(), %{email: email})
      assert organization.email == email
      assert Accounts.get_organization!(organization.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{organization: organization_fixture()}
    end

    test "sends token through notification", %{organization: organization} do
      token =
        extract_organization_token(fn url ->
          Accounts.deliver_update_email_instructions(organization, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert organization_token = Repo.get_by(OrganizationToken, token: :crypto.hash(:sha256, token))
      assert organization_token.organization_id == organization.id
      assert organization_token.sent_to == organization.email
      assert organization_token.context == "change:current@example.com"
    end
  end

  describe "update_organization_email/2" do
    setup do
      organization = organization_fixture()
      email = unique_organization_email()

      token =
        extract_organization_token(fn url ->
          Accounts.deliver_update_email_instructions(%{organization | email: email}, organization.email, url)
        end)

      %{organization: organization, token: token, email: email}
    end

    test "updates the email with a valid token", %{organization: organization, token: token, email: email} do
      assert Accounts.update_organization_email(organization, token) == :ok
      changed_organization = Repo.get!(Organization, organization.id)
      assert changed_organization.email != organization.email
      assert changed_organization.email == email
      assert changed_organization.confirmed_at
      assert changed_organization.confirmed_at != organization.confirmed_at
      refute Repo.get_by(OrganizationToken, organization_id: organization.id)
    end

    test "does not update email with invalid token", %{organization: organization} do
      assert Accounts.update_organization_email(organization, "oops") == :error
      assert Repo.get!(Organization, organization.id).email == organization.email
      assert Repo.get_by(OrganizationToken, organization_id: organization.id)
    end

    test "does not update email if organization email changed", %{organization: organization, token: token} do
      assert Accounts.update_organization_email(%{organization | email: "current@example.com"}, token) == :error
      assert Repo.get!(Organization, organization.id).email == organization.email
      assert Repo.get_by(OrganizationToken, organization_id: organization.id)
    end

    test "does not update email if token expired", %{organization: organization, token: token} do
      {1, nil} = Repo.update_all(OrganizationToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_organization_email(organization, token) == :error
      assert Repo.get!(Organization, organization.id).email == organization.email
      assert Repo.get_by(OrganizationToken, organization_id: organization.id)
    end
  end

  describe "change_organization_password/2" do
    test "returns a organization changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_organization_password(%Organization{})
      assert changeset.required == [:password]
    end
  end

  describe "update_organization_password/3" do
    setup do
      %{organization: organization_fixture()}
    end

    test "validates password", %{organization: organization} do
      {:error, changeset} =
        Accounts.update_organization_password(organization, valid_organization_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{organization: organization} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_organization_password(organization, valid_organization_password(), %{password: too_long})

      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{organization: organization} do
      {:error, changeset} =
        Accounts.update_organization_password(organization, "invalid", %{password: valid_organization_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{organization: organization} do
      {:ok, organization} =
        Accounts.update_organization_password(organization, valid_organization_password(), %{
          password: "new valid password"
        })

      assert is_nil(organization.password)
      assert Accounts.get_organization_by_email_and_password(organization.email, "new valid password")
    end

    test "deletes all tokens for the given organization", %{organization: organization} do
      _ = Accounts.generate_organization_session_token(organization)

      {:ok, _} =
        Accounts.update_organization_password(organization, valid_organization_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(OrganizationToken, organization_id: organization.id)
    end
  end

  describe "generate_organization_session_token/1" do
    setup do
      %{organization: organization_fixture()}
    end

    test "generates a token", %{organization: organization} do
      token = Accounts.generate_organization_session_token(organization)
      assert organization_token = Repo.get_by(OrganizationToken, token: token)
      assert organization_token.context == "session"

      # Creating the same token for another organization should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%OrganizationToken{
          token: organization_token.token,
          organization_id: organization_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_organization_by_session_token/1" do
    setup do
      organization = organization_fixture()
      token = Accounts.generate_organization_session_token(organization)
      %{organization: organization, token: token}
    end

    test "returns organization by token", %{organization: organization, token: token} do
      assert session_organization = Accounts.get_organization_by_session_token(token)
      assert session_organization.id == organization.id
    end

    test "does not return organization for invalid token" do
      refute Accounts.get_organization_by_session_token("oops")
    end

    test "does not return organization for expired token", %{token: token} do
      {1, nil} = Repo.update_all(OrganizationToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_organization_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      organization = organization_fixture()
      token = Accounts.generate_organization_session_token(organization)
      assert Accounts.delete_session_token(token) == :ok
      refute Accounts.get_organization_by_session_token(token)
    end
  end

  describe "deliver_organization_confirmation_instructions/2" do
    setup do
      %{organization: organization_fixture()}
    end

    test "sends token through notification", %{organization: organization} do
      token =
        extract_organization_token(fn url ->
          Accounts.deliver_organization_confirmation_instructions(organization, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert organization_token = Repo.get_by(OrganizationToken, token: :crypto.hash(:sha256, token))
      assert organization_token.organization_id == organization.id
      assert organization_token.sent_to == organization.email
      assert organization_token.context == "confirm"
    end
  end

  describe "confirm_organization/2" do
    setup do
      organization = organization_fixture()

      token =
        extract_organization_token(fn url ->
          Accounts.deliver_organization_confirmation_instructions(organization, url)
        end)

      %{organization: organization, token: token}
    end

    test "confirms the email with a valid token", %{organization: organization, token: token} do
      assert {:ok, confirmed_organization} = Accounts.confirm_organization(token)
      assert confirmed_organization.confirmed_at
      assert confirmed_organization.confirmed_at != organization.confirmed_at
      assert Repo.get!(Organization, organization.id).confirmed_at
      refute Repo.get_by(OrganizationToken, organization_id: organization.id)
    end

    test "does not confirm with invalid token", %{organization: organization} do
      assert Accounts.confirm_organization("oops") == :error
      refute Repo.get!(Organization, organization.id).confirmed_at
      assert Repo.get_by(OrganizationToken, organization_id: organization.id)
    end

    test "does not confirm email if token expired", %{organization: organization, token: token} do
      {1, nil} = Repo.update_all(OrganizationToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_organization(token) == :error
      refute Repo.get!(Organization, organization.id).confirmed_at
      assert Repo.get_by(OrganizationToken, organization_id: organization.id)
    end
  end

  describe "deliver_organization_reset_password_instructions/2" do
    setup do
      %{organization: organization_fixture()}
    end

    test "sends token through notification", %{organization: organization} do
      token =
        extract_organization_token(fn url ->
          Accounts.deliver_organization_reset_password_instructions(organization, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert organization_token = Repo.get_by(OrganizationToken, token: :crypto.hash(:sha256, token))
      assert organization_token.organization_id == organization.id
      assert organization_token.sent_to == organization.email
      assert organization_token.context == "reset_password"
    end
  end

  describe "get_organization_by_reset_password_token/1" do
    setup do
      organization = organization_fixture()

      token =
        extract_organization_token(fn url ->
          Accounts.deliver_organization_reset_password_instructions(organization, url)
        end)

      %{organization: organization, token: token}
    end

    test "returns the organization with valid token", %{organization: %{id: id}, token: token} do
      assert %Organization{id: ^id} = Accounts.get_organization_by_reset_password_token(token)
      assert Repo.get_by(OrganizationToken, organization_id: id)
    end

    test "does not return the organization with invalid token", %{organization: organization} do
      refute Accounts.get_organization_by_reset_password_token("oops")
      assert Repo.get_by(OrganizationToken, organization_id: organization.id)
    end

    test "does not return the organization if token expired", %{organization: organization, token: token} do
      {1, nil} = Repo.update_all(OrganizationToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_organization_by_reset_password_token(token)
      assert Repo.get_by(OrganizationToken, organization_id: organization.id)
    end
  end

  describe "reset_organization_password/2" do
    setup do
      %{organization: organization_fixture()}
    end

    test "validates password", %{organization: organization} do
      {:error, changeset} =
        Accounts.reset_organization_password(organization, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{organization: organization} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_organization_password(organization, %{password: too_long})
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{organization: organization} do
      {:ok, updated_organization} = Accounts.reset_organization_password(organization, %{password: "new valid password"})
      assert is_nil(updated_organization.password)
      assert Accounts.get_organization_by_email_and_password(organization.email, "new valid password")
    end

    test "deletes all tokens for the given organization", %{organization: organization} do
      _ = Accounts.generate_organization_session_token(organization)
      {:ok, _} = Accounts.reset_organization_password(organization, %{password: "new valid password"})
      refute Repo.get_by(OrganizationToken, organization_id: organization.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%Organization{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
