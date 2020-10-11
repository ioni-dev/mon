defmodule Mon.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mon.Accounts` context.
  """

  def unique_driver_email, do: "driver#{System.unique_integer()}@example.com"
  def valid_driver_password, do: "hello world!"

  def driver_fixture(attrs \\ %{}) do
    {:ok, driver} =
      attrs
      |> Enum.into(%{
        email: unique_driver_email(),
        password: valid_driver_password()
      })
      |> Mon.Accounts.register_driver()

    driver
  end

  def extract_driver_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.body, "[TOKEN]")
    token
  end

  def unique_client_email, do: "client#{System.unique_integer()}@example.com"
  def valid_client_password, do: "hello world!"

  def client_fixture(attrs \\ %{}) do
    {:ok, client} =
      attrs
      |> Enum.into(%{
        email: unique_client_email(),
        password: valid_client_password()
      })
      |> Mon.Accounts.register_client()

    client
  end

  def extract_client_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.body, "[TOKEN]")
    token
  end

  def unique_organization_email, do: "organization#{System.unique_integer()}@example.com"
  def valid_organization_password, do: "hello world!"

  def organization_fixture(attrs \\ %{}) do
    {:ok, organization} =
      attrs
      |> Enum.into(%{
        email: unique_organization_email(),
        password: valid_organization_password()
      })
      |> Mon.Accounts.register_organization()

    organization
  end

  def extract_organization_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.body, "[TOKEN]")
    token
  end
end
