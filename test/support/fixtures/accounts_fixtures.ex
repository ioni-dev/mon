defmodule Mon.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mon.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: unique_user_email(),
        password: valid_user_password()
      })
      |> Mon.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
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
