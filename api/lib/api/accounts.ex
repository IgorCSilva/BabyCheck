defmodule Api.Accounts do
  @moduledoc """
  Accounts: registration, authentication, sessions, and password resets.
  """

  alias Api.Accounts.{User, UserToken}
  alias Api.Repo

  ## Users

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(String.trim(email)))
  end

  @doc """
  Authenticates a user by email and password.

  Runs `Bcrypt.no_user_verify/0` when no account matches the email, so an
  unknown-email request takes the same amount of time as a wrong-password
  one — the response time itself shouldn't reveal whether the email exists.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.hashed_password) -> user
      user -> nil
      true ->
        Bcrypt.no_user_verify()
        nil
    end
  end

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  ## Sessions (Guardian access token + rotating refresh-token cookie)

  @doc """
  Issues a fresh access token + refresh token pair for `user`.

  `remember_me?` is stored alongside the refresh token so it survives
  rotation on `refresh_session/1` — it's what the controller later uses to
  decide whether the refresh cookie gets a long `max_age` (persists after
  the browser closes) or none (a session cookie, gone once it does).
  """
  def create_session(user, remember_me?) do
    {:ok, access_token, _claims} = Api.Guardian.encode_and_sign(user)
    {raw_refresh_token, refresh_token} = UserToken.build_token(user, "refresh_token", remember_me: remember_me?)

    with {:ok, _} <- Repo.insert(refresh_token) do
      {:ok, access_token, raw_refresh_token}
    end
  end

  @doc """
  Verifies a raw refresh token, rotates it (old one deleted, new one
  issued with the same `remember_me?`), and mints a new access token.
  """
  def refresh_session(raw_refresh_token) do
    with {:ok, query} <- UserToken.verify_token_query(raw_refresh_token, "refresh_token"),
         {user, old_token} <- Repo.one(query) do
      Repo.transaction(fn ->
        Repo.delete!(old_token)

        {raw_token, new_token} =
          UserToken.build_token(user, "refresh_token", remember_me: old_token.remember_me)

        {:ok, _} = Repo.insert(new_token)
        {:ok, access_token, _claims} = Api.Guardian.encode_and_sign(user)

        {user, access_token, raw_token, old_token.remember_me}
      end)
    else
      _ -> {:error, :invalid_or_expired}
    end
  end

  def revoke_refresh_token(raw_refresh_token) do
    with {:ok, query} <- UserToken.verify_token_query(raw_refresh_token, "refresh_token"),
         {_user, token} <- Repo.one(query) do
      Repo.delete(token)
    end

    :ok
  end

  ## Password reset

  def deliver_user_reset_password_instructions(user, reset_url_fun) when is_function(reset_url_fun, 1) do
    {raw_token, user_token} = UserToken.build_token(user, "reset_password")
    {:ok, _} = Repo.insert(user_token)
    Api.Accounts.UserNotifier.deliver_reset_password_instructions(user, reset_url_fun.(raw_token))
  end

  def get_user_by_reset_password_token(raw_token) do
    with {:ok, query} <- UserToken.verify_token_query(raw_token, "reset_password"),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Sets a new password and, as a security measure, revokes every refresh
  token the user has — a password reset ends every other active session.
  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, fn _ -> UserToken.by_user_and_context_query(user, "refresh_token") end)
    |> Ecto.Multi.delete_all(:reset_tokens, fn _ ->
      UserToken.by_user_and_context_query(user, "reset_password")
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _changes} -> {:error, changeset}
    end
  end
end
