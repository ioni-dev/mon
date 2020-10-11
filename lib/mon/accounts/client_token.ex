defmodule Mon.Accounts.ClientToken do
  use Ecto.Schema
  import Ecto.Query

  @hash_algorithm :sha256
  @rand_size 32

  # It is very important to keep the reset password token expiry short,
  # since someone with access to the email may take over the account.
  @reset_password_validity_in_days 1
  @confirm_validity_in_days 7
  @change_email_validity_in_days 7
  @session_validity_in_days 60

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "clients_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :client, Mon.Accounts.Client

    timestamps(updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.
  """
  def build_session_token(client) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %Mon.Accounts.ClientToken{token: token, context: "session", client_id: client.id}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the client found by the token.
  """
  def verify_session_token_query(token) do
    query =
      from token in token_and_context_query(token, "session"),
        join: client in assoc(token, :client),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: client

    {:ok, query}
  end

  @doc """
  Builds a token with a hashed counter part.

  The non-hashed token is sent to the client email while the
  hashed part is stored in the database, to avoid reconstruction.
  The token is valid for a week as long as clients don't change
  their email.
  """
  def build_email_token(client, context) do
    build_hashed_token(client, context, client.email)
  end

  defp build_hashed_token(client, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %Mon.Accounts.ClientToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       client_id: client.id
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the client found by the token.
  """
  def verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        days = days_for_context(context)

        query =
          from token in token_and_context_query(hashed_token, context),
            join: client in assoc(token, :client),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == client.email,
            select: client

        {:ok, query}

      :error ->
        :error
    end
  end

  defp days_for_context("confirm"), do: @confirm_validity_in_days
  defp days_for_context("reset_password"), do: @reset_password_validity_in_days

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the client token record.
  """
  def verify_change_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Returns the given token with the given context.
  """
  def token_and_context_query(token, context) do
    from Mon.Accounts.ClientToken, where: [token: ^token, context: ^context]
  end

  @doc """
  Gets all tokens for the given client for the given contexts.
  """
  def client_and_contexts_query(client, :all) do
    from t in Mon.Accounts.ClientToken, where: t.client_id == ^client.id
  end

  def client_and_contexts_query(client, [_ | _] = contexts) do
    from t in Mon.Accounts.ClientToken, where: t.client_id == ^client.id and t.context in ^contexts
  end
end
