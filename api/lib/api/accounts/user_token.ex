defmodule Api.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query

  @hash_algorithm :sha256
  @rand_size 32

  @reset_password_validity_in_seconds 60 * 60
  @refresh_token_validity_in_seconds 60 * 60 * 24 * 30

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :remember_me, :boolean, default: false
    belongs_to :user, Api.Accounts.User

    timestamps(updated_at: false, type: :utc_datetime)
  end

  @doc """
  Builds an opaque, random token for the given context, alongside the
  `UserToken` struct (holding only its hash) that should be persisted.
  Only the raw token is ever sent to the client/email — the database never
  stores anything an attacker could replay straight out of a dump.
  """
  def build_token(user, context, opts \\ []) do
    raw_token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, raw_token)

    token = %__MODULE__{
      token: hashed_token,
      context: context,
      sent_to: Keyword.get(opts, :sent_to, user.email),
      remember_me: Keyword.get(opts, :remember_me, false),
      user_id: user.id
    }

    {Base.url_encode64(raw_token, padding: false), token}
  end

  @doc """
  Query matching a raw token + context pair that hasn't expired, joined with
  its user. Returns an empty result for an unknown, wrong-context, or
  expired token — the caller can't distinguish those cases, which is the
  point (no information leak about *why* a token didn't work).
  """
  def verify_token_query(raw_token, context) do
    case decode_token(raw_token) do
      {:ok, hashed_token} ->
        query =
          from token in by_context_query(context),
            where: token.token == ^hashed_token,
            where: token.inserted_at > ago(^validity_in_seconds(context), "second"),
            join: user in assoc(token, :user),
            select: {user, token}

        {:ok, query}

      :error ->
        :error
    end
  end

  def by_context_query(context) do
    from token in __MODULE__, where: token.context == ^context
  end

  def by_user_and_context_query(user, context) do
    from token in __MODULE__, where: token.user_id == ^user.id and token.context == ^context
  end

  defp decode_token(raw_token) do
    case Base.url_decode64(raw_token, padding: false) do
      {:ok, decoded} -> {:ok, :crypto.hash(@hash_algorithm, decoded)}
      :error -> :error
    end
  end

  defp validity_in_seconds("reset_password"), do: @reset_password_validity_in_seconds
  defp validity_in_seconds("refresh_token"), do: @refresh_token_validity_in_seconds
end
