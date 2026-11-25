defmodule ApiWeb.AuthController do
  use ApiWeb, :controller

  alias Api.Accounts
  alias Api.Accounts.User

  action_fallback ApiWeb.FallbackController

  @refresh_cookie "refresh_token"
  @session_max_age 60 * 60 * 24
  @remember_me_max_age 60 * 60 * 24 * 30

  # New accounts are logged straight in — there's no separate "now go log
  # in" step after signing up.
  def register(conn, params) do
    with {:ok, user} <- Accounts.register_user(params) do
      issue_session(conn, user, true, :created)
    end
  end

  def login(conn, %{"email" => email, "password" => password} = params) do
    remember_me? = truthy?(params["remember_me"])

    case Accounts.get_user_by_email_and_password(email, password) do
      %User{} = user -> issue_session(conn, user, remember_me?, :ok)
      nil -> {:error, :invalid_credentials}
    end
  end

  def refresh(conn, _params) do
    with token when is_binary(token) <- conn.cookies[@refresh_cookie],
         {:ok, {user, access_token, raw_refresh_token, remember_me?}} <-
           Accounts.refresh_session(token) do
      conn
      |> put_refresh_cookie(raw_refresh_token, remember_me?)
      |> render(:session, user: user, access_token: access_token)
    else
      # The refresh token is rotated on every successful call, so two
      # requests racing on the same (about-to-be-rotated) cookie value is
      # expected under normal use. Deliberately not deleting the cookie
      # here: the loser of that race must not be able to log out a
      # perfectly valid session the winner just legitimately renewed. Only
      # an explicit logout deletes the cookie.
      _ -> {:error, :invalid_or_expired}
    end
  end

  def logout(conn, _params) do
    case conn.cookies[@refresh_cookie] do
      token when is_binary(token) -> Accounts.revoke_refresh_token(token)
      _ -> :ok
    end

    conn
    |> delete_refresh_cookie()
    |> send_resp(:no_content, "")
  end

  # Always responds the same way whether or not the email exists, so the
  # response can't be used to enumerate registered accounts.
  def request_password_reset(conn, %{"email" => email}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(user, &reset_password_url/1)
    end

    send_resp(conn, :no_content, "")
  end

  # Resetting a password proves identity as surely as logging in does, so
  # it also logs the user straight back in.
  def reset_password(conn, %{"token" => token} = params) do
    with %User{} = user <- Accounts.get_user_by_reset_password_token(token),
         {:ok, user} <- Accounts.reset_user_password(user, params) do
      issue_session(conn, user, true, :ok)
    else
      nil -> {:error, :invalid_or_expired_token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp issue_session(conn, user, remember_me?, status) do
    {:ok, access_token, raw_refresh_token} = Accounts.create_session(user, remember_me?)

    conn
    |> put_status(status)
    |> put_refresh_cookie(raw_refresh_token, remember_me?)
    |> render(:session, user: user, access_token: access_token)
  end

  defp put_refresh_cookie(conn, raw_refresh_token, remember_me?) do
    max_age = if remember_me?, do: @remember_me_max_age, else: @session_max_age

    put_resp_cookie(conn, @refresh_cookie, raw_refresh_token,
      http_only: true,
      same_site: same_site_policy(),
      secure: secure_cookies?(),
      max_age: max_age,
      path: "/api/auth"
    )
  end

  defp delete_refresh_cookie(conn) do
    delete_resp_cookie(conn, @refresh_cookie,
      path: "/api/auth",
      same_site: same_site_policy(),
      secure: secure_cookies?()
    )
  end

  defp secure_cookies?, do: Application.get_env(:api, :env) == :prod

  # The Vue frontend and the API are served from different origins in
  # production, so the refresh cookie needs SameSite=None (which browsers
  # only honor alongside Secure) to survive cross-site fetch requests.
  # Locally both run on localhost (same "site", different ports), where
  # requiring Secure would mean dev needs HTTPS just to keep a session.
  defp same_site_policy, do: if(secure_cookies?(), do: "None", else: "Lax")

  defp truthy?(value), do: value in [true, "true", "1", 1]

  defp reset_password_url(token), do: "#{web_base_url()}/reset-password/#{token}"
  defp web_base_url, do: Application.get_env(:api, :web_base_url, "http://localhost:3000")
end
