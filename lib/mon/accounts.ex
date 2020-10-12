defmodule Mon.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Mon.Repo
  alias Mon.Accounts.{User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset = user |> User.email_changeset(%{email: email}) |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc """
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, &Routes.user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :confirm, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :confirm, &1))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &Routes.user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end
  alias Mon.Accounts.{Client, ClientToken, ClientNotifier}

  ## Database getters

  @doc """
  Gets a client by email.

  ## Examples

      iex> get_client_by_email("foo@example.com")
      %Client{}

      iex> get_client_by_email("unknown@example.com")
      nil

  """
  def get_client_by_email(email) when is_binary(email) do
    Repo.get_by(Client, email: email)
  end

  @doc """
  Gets a client by email and password.

  ## Examples

      iex> get_client_by_email_and_password("foo@example.com", "correct_password")
      %Client{}

      iex> get_client_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_client_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    client = Repo.get_by(Client, email: email)
    if Client.valid_password?(client, password), do: client
  end

  @doc """
  Gets a single client.

  Raises `Ecto.NoResultsError` if the Client does not exist.

  ## Examples

      iex> get_client!(123)
      %Client{}

      iex> get_client!(456)
      ** (Ecto.NoResultsError)

  """
  def get_client!(id), do: Repo.get!(Client, id)

  ## Client registration

  @doc """
  Registers a client.

  ## Examples

      iex> register_client(%{field: value})
      {:ok, %Client{}}

      iex> register_client(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_client(attrs) do
    %Client{}
    |> Client.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking client changes.

  ## Examples

      iex> change_client_registration(client)
      %Ecto.Changeset{data: %Client{}}

  """
  def change_client_registration(%Client{} = client, attrs \\ %{}) do
    Client.registration_changeset(client, attrs)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the client email.

  ## Examples

      iex> change_client_email(client)
      %Ecto.Changeset{data: %Client{}}

  """
  def change_client_email(client, attrs \\ %{}) do
    Client.email_changeset(client, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_client_email(client, "valid password", %{email: ...})
      {:ok, %Client{}}

      iex> apply_client_email(client, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_client_email(client, password, attrs) do
    client
    |> Client.email_changeset(attrs)
    |> Client.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the client email using the given token.

  If the token matches, the client email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_client_email(client, token) do
    context = "change:#{client.email}"

    with {:ok, query} <- ClientToken.verify_change_email_token_query(token, context),
         %ClientToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(client_email_multi(client, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp client_email_multi(client, email, context) do
    changeset = client |> Client.email_changeset(%{email: email}) |> Client.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:client, changeset)
    |> Ecto.Multi.delete_all(:tokens, ClientToken.client_and_contexts_query(client, [context]))
  end

  @doc """
  Delivers the update email instructions to the given client.

  ## Examples

      iex> deliver_update_email_instructions(client, current_email, &Routes.client_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%Client{} = client, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, client_token} = ClientToken.build_email_token(client, "change:#{current_email}")

    Repo.insert!(client_token)
    ClientNotifier.deliver_update_email_instructions(client, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the client password.

  ## Examples

      iex> change_client_password(client)
      %Ecto.Changeset{data: %Client{}}

  """
  def change_client_password(client, attrs \\ %{}) do
    Client.password_changeset(client, attrs)
  end

  @doc """
  Updates the client password.

  ## Examples

      iex> update_client_password(client, "valid password", %{password: ...})
      {:ok, %Client{}}

      iex> update_client_password(client, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_client_password(client, password, attrs) do
    changeset =
      client
      |> Client.password_changeset(attrs)
      |> Client.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:client, changeset)
    |> Ecto.Multi.delete_all(:tokens, ClientToken.client_and_contexts_query(client, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{client: client}} -> {:ok, client}
      {:error, :client, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_client_session_token(client) do
    {token, client_token} = ClientToken.build_session_token(client)
    Repo.insert!(client_token)
    token
  end

  @doc """
  Gets the client with the given signed token.
  """
  def get_client_by_session_token(token) do
    {:ok, query} = ClientToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(ClientToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given client.

  ## Examples

      iex> deliver_client_confirmation_instructions(client, &Routes.client_confirmation_url(conn, :confirm, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_client_confirmation_instructions(confirmed_client, &Routes.client_confirmation_url(conn, :confirm, &1))
      {:error, :already_confirmed}

  """
  def deliver_client_confirmation_instructions(%Client{} = client, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if client.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, client_token} = ClientToken.build_email_token(client, "confirm")
      Repo.insert!(client_token)
      ClientNotifier.deliver_confirmation_instructions(client, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a client by the given token.

  If the token matches, the client account is marked as confirmed
  and the token is deleted.
  """
  def confirm_client(token) do
    with {:ok, query} <- ClientToken.verify_email_token_query(token, "confirm"),
         %Client{} = client <- Repo.one(query),
         {:ok, %{client: client}} <- Repo.transaction(confirm_client_multi(client)) do
      {:ok, client}
    else
      _ -> :error
    end
  end

  defp confirm_client_multi(client) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:client, Client.confirm_changeset(client))
    |> Ecto.Multi.delete_all(:tokens, ClientToken.client_and_contexts_query(client, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given client.

  ## Examples

      iex> deliver_client_reset_password_instructions(client, &Routes.client_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_client_reset_password_instructions(%Client{} = client, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, client_token} = ClientToken.build_email_token(client, "reset_password")
    Repo.insert!(client_token)
    ClientNotifier.deliver_reset_password_instructions(client, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the client by reset password token.

  ## Examples

      iex> get_client_by_reset_password_token("validtoken")
      %Client{}

      iex> get_client_by_reset_password_token("invalidtoken")
      nil

  """
  def get_client_by_reset_password_token(token) do
    with {:ok, query} <- ClientToken.verify_email_token_query(token, "reset_password"),
         %Client{} = client <- Repo.one(query) do
      client
    else
      _ -> nil
    end
  end

  @doc """
  Resets the client password.

  ## Examples

      iex> reset_client_password(client, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Client{}}

      iex> reset_client_password(client, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_client_password(client, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:client, Client.password_changeset(client, attrs))
    |> Ecto.Multi.delete_all(:tokens, ClientToken.client_and_contexts_query(client, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{client: client}} -> {:ok, client}
      {:error, :client, changeset, _} -> {:error, changeset}
    end
  end
  alias Mon.Accounts.{Organization, OrganizationToken, OrganizationNotifier}

  ## Database getters

  @doc """
  Gets a organization by email.

  ## Examples

      iex> get_organization_by_email("foo@example.com")
      %Organization{}

      iex> get_organization_by_email("unknown@example.com")
      nil

  """
  def get_organization_by_email(email) when is_binary(email) do
    Repo.get_by(Organization, email: email)
  end

  @doc """
  Gets a organization by email and password.

  ## Examples

      iex> get_organization_by_email_and_password("foo@example.com", "correct_password")
      %Organization{}

      iex> get_organization_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_organization_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    organization = Repo.get_by(Organization, email: email)
    if Organization.valid_password?(organization, password), do: organization
  end

  @doc """
  Gets a single organization.

  Raises `Ecto.NoResultsError` if the Organization does not exist.

  ## Examples

      iex> get_organization!(123)
      %Organization{}

      iex> get_organization!(456)
      ** (Ecto.NoResultsError)

  """
  def get_organization!(id), do: Repo.get!(Organization, id)

  ## Organization registration

  @doc """
  Registers a organization.

  ## Examples

      iex> register_organization(%{field: value})
      {:ok, %Organization{}}

      iex> register_organization(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_organization(attrs) do
    %Organization{}
    |> Organization.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking organization changes.

  ## Examples

      iex> change_organization_registration(organization)
      %Ecto.Changeset{data: %Organization{}}

  """
  def change_organization_registration(%Organization{} = organization, attrs \\ %{}) do
    Organization.registration_changeset(organization, attrs)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the organization email.

  ## Examples

      iex> change_organization_email(organization)
      %Ecto.Changeset{data: %Organization{}}

  """
  def change_organization_email(organization, attrs \\ %{}) do
    Organization.email_changeset(organization, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_organization_email(organization, "valid password", %{email: ...})
      {:ok, %Organization{}}

      iex> apply_organization_email(organization, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_organization_email(organization, password, attrs) do
    organization
    |> Organization.email_changeset(attrs)
    |> Organization.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the organization email using the given token.

  If the token matches, the organization email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_organization_email(organization, token) do
    context = "change:#{organization.email}"

    with {:ok, query} <- OrganizationToken.verify_change_email_token_query(token, context),
         %OrganizationToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(organization_email_multi(organization, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp organization_email_multi(organization, email, context) do
    changeset = organization |> Organization.email_changeset(%{email: email}) |> Organization.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:organization, changeset)
    |> Ecto.Multi.delete_all(:tokens, OrganizationToken.organization_and_contexts_query(organization, [context]))
  end

  @doc """
  Delivers the update email instructions to the given organization.

  ## Examples

      iex> deliver_update_email_instructions(organization, current_email, &Routes.organization_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%Organization{} = organization, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, organization_token} = OrganizationToken.build_email_token(organization, "change:#{current_email}")

    Repo.insert!(organization_token)
    OrganizationNotifier.deliver_update_email_instructions(organization, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the organization password.

  ## Examples

      iex> change_organization_password(organization)
      %Ecto.Changeset{data: %Organization{}}

  """
  def change_organization_password(organization, attrs \\ %{}) do
    Organization.password_changeset(organization, attrs)
  end

  @doc """
  Updates the organization password.

  ## Examples

      iex> update_organization_password(organization, "valid password", %{password: ...})
      {:ok, %Organization{}}

      iex> update_organization_password(organization, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_organization_password(organization, password, attrs) do
    changeset =
      organization
      |> Organization.password_changeset(attrs)
      |> Organization.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:organization, changeset)
    |> Ecto.Multi.delete_all(:tokens, OrganizationToken.organization_and_contexts_query(organization, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{organization: organization}} -> {:ok, organization}
      {:error, :organization, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_organization_session_token(organization) do
    {token, organization_token} = OrganizationToken.build_session_token(organization)
    Repo.insert!(organization_token)
    token
  end

  @doc """
  Gets the organization with the given signed token.
  """
  def get_organization_by_session_token(token) do
    {:ok, query} = OrganizationToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(OrganizationToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given organization.

  ## Examples

      iex> deliver_organization_confirmation_instructions(organization, &Routes.organization_confirmation_url(conn, :confirm, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_organization_confirmation_instructions(confirmed_organization, &Routes.organization_confirmation_url(conn, :confirm, &1))
      {:error, :already_confirmed}

  """
  def deliver_organization_confirmation_instructions(%Organization{} = organization, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if organization.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, organization_token} = OrganizationToken.build_email_token(organization, "confirm")
      Repo.insert!(organization_token)
      OrganizationNotifier.deliver_confirmation_instructions(organization, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a organization by the given token.

  If the token matches, the organization account is marked as confirmed
  and the token is deleted.
  """
  def confirm_organization(token) do
    with {:ok, query} <- OrganizationToken.verify_email_token_query(token, "confirm"),
         %Organization{} = organization <- Repo.one(query),
         {:ok, %{organization: organization}} <- Repo.transaction(confirm_organization_multi(organization)) do
      {:ok, organization}
    else
      _ -> :error
    end
  end

  defp confirm_organization_multi(organization) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:organization, Organization.confirm_changeset(organization))
    |> Ecto.Multi.delete_all(:tokens, OrganizationToken.organization_and_contexts_query(organization, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given organization.

  ## Examples

      iex> deliver_organization_reset_password_instructions(organization, &Routes.organization_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_organization_reset_password_instructions(%Organization{} = organization, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, organization_token} = OrganizationToken.build_email_token(organization, "reset_password")
    Repo.insert!(organization_token)
    OrganizationNotifier.deliver_reset_password_instructions(organization, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the organization by reset password token.

  ## Examples

      iex> get_organization_by_reset_password_token("validtoken")
      %Organization{}

      iex> get_organization_by_reset_password_token("invalidtoken")
      nil

  """
  def get_organization_by_reset_password_token(token) do
    with {:ok, query} <- OrganizationToken.verify_email_token_query(token, "reset_password"),
         %Organization{} = organization <- Repo.one(query) do
      organization
    else
      _ -> nil
    end
  end

  @doc """
  Resets the organization password.

  ## Examples

      iex> reset_organization_password(organization, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Organization{}}

      iex> reset_organization_password(organization, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_organization_password(organization, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:organization, Organization.password_changeset(organization, attrs))
    |> Ecto.Multi.delete_all(:tokens, OrganizationToken.organization_and_contexts_query(organization, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{organization: organization}} -> {:ok, organization}
      {:error, :organization, changeset, _} -> {:error, changeset}
    end
  end
end
