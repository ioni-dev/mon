defmodule MonWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MonWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import MonWeb.ConnCase

      alias MonWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint MonWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Mon.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Mon.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in drivers.

      setup :register_and_log_in_driver

  It stores an updated connection and a registered driver in the
  test context.
  """
  def register_and_log_in_driver(%{conn: conn}) do
    driver = Mon.AccountsFixtures.driver_fixture()
    %{conn: log_in_driver(conn, driver), driver: driver}
  end

  @doc """
  Logs the given `driver` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_driver(conn, driver) do
    token = Mon.Accounts.generate_driver_session_token(driver)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:driver_token, token)
  end

  @doc """
  Setup helper that registers and logs in clients.

      setup :register_and_log_in_client

  It stores an updated connection and a registered client in the
  test context.
  """
  def register_and_log_in_client(%{conn: conn}) do
    client = Mon.AccountsFixtures.client_fixture()
    %{conn: log_in_client(conn, client), client: client}
  end

  @doc """
  Logs the given `client` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_client(conn, client) do
    token = Mon.Accounts.generate_client_session_token(client)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:client_token, token)
  end

  @doc """
  Setup helper that registers and logs in organizations.

      setup :register_and_log_in_organization

  It stores an updated connection and a registered organization in the
  test context.
  """
  def register_and_log_in_organization(%{conn: conn}) do
    organization = Mon.AccountsFixtures.organization_fixture()
    %{conn: log_in_organization(conn, organization), organization: organization}
  end

  @doc """
  Logs the given `organization` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_organization(conn, organization) do
    token = Mon.Accounts.generate_organization_session_token(organization)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:organization_token, token)
  end
end
