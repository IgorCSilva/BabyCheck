defmodule ApiWeb.AuthControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Api.Accounts

  @valid_attrs %{
    "email" => "parent@example.com",
    "password" => "supersecret123",
    "password_confirmation" => "supersecret123"
  }

  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      @valid_attrs
      |> Map.merge(attrs)
      |> Accounts.register_user()

    user
  end

  describe "POST /api/auth/register" do
    test "creates an account and logs the user straight in", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", @valid_attrs)

      assert %{"data" => %{"user" => user, "access_token" => token}} = json_response(conn, 201)
      assert user["email"] == "parent@example.com"
      assert is_binary(token)
      assert conn.resp_cookies["refresh_token"]
    end

    test "rejects mismatched password confirmation", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/register", Map.put(@valid_attrs, "password_confirmation", "nope"))

      assert %{"errors" => %{"password_confirmation" => _}} = json_response(conn, 422)
    end

    test "rejects a duplicate email", %{conn: conn} do
      user_fixture()
      conn = post(conn, ~p"/api/auth/register", @valid_attrs)
      assert %{"errors" => %{"email" => _}} = json_response(conn, 422)
    end
  end

  describe "POST /api/auth/login" do
    test "logs in with correct credentials", %{conn: conn} do
      user_fixture()

      conn =
        post(conn, ~p"/api/auth/login", %{"email" => "parent@example.com", "password" => "supersecret123"})

      assert %{"data" => %{"user" => %{"email" => "parent@example.com"}, "access_token" => token}} =
               json_response(conn, 200)

      assert is_binary(token)
    end

    test "rejects wrong password", %{conn: conn} do
      user_fixture()

      conn =
        post(conn, ~p"/api/auth/login", %{"email" => "parent@example.com", "password" => "wrongpass"})

      assert %{"errors" => %{"code" => "invalid_credentials"}} = json_response(conn, 401)
    end

    test "sets a persistent cookie when remember_me is true, a session cookie otherwise", %{
      conn: conn
    } do
      user_fixture()

      remembered =
        post(conn, ~p"/api/auth/login", %{
          "email" => "parent@example.com",
          "password" => "supersecret123",
          "remember_me" => true
        })

      not_remembered =
        post(conn, ~p"/api/auth/login", %{
          "email" => "parent@example.com",
          "password" => "supersecret123",
          "remember_me" => false
        })

      assert remembered.resp_cookies["refresh_token"].max_age == 60 * 60 * 24 * 30
      assert not_remembered.resp_cookies["refresh_token"].max_age == 60 * 60 * 24
    end
  end

  describe "GET /api/me" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/me")
      assert json_response(conn, 401)
    end

    test "returns the current user with a valid access token", %{conn: conn} do
      user = user_fixture()
      {:ok, access_token, _refresh} = Accounts.create_session(user, false)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> get(~p"/api/me")

      assert %{"data" => %{"email" => "parent@example.com"}} = json_response(conn, 200)
    end
  end

  describe "session refresh + logout" do
    test "refresh issues a new access token from the refresh cookie", %{conn: conn} do
      user_fixture()

      login_conn =
        post(conn, ~p"/api/auth/login", %{"email" => "parent@example.com", "password" => "supersecret123"})

      refresh_cookie = login_conn.resp_cookies["refresh_token"].value

      refresh_conn =
        conn
        |> put_req_cookie("refresh_token", refresh_cookie)
        |> post(~p"/api/auth/refresh")

      assert %{"data" => %{"access_token" => new_token}} = json_response(refresh_conn, 200)
      assert is_binary(new_token)
    end

    test "logout revokes the refresh token", %{conn: conn} do
      user_fixture()

      login_conn =
        post(conn, ~p"/api/auth/login", %{"email" => "parent@example.com", "password" => "supersecret123"})

      refresh_cookie = login_conn.resp_cookies["refresh_token"].value

      logout_conn =
        conn
        |> put_req_cookie("refresh_token", refresh_cookie)
        |> delete(~p"/api/auth/logout")

      assert response(logout_conn, 204)

      retry_conn =
        conn
        |> put_req_cookie("refresh_token", refresh_cookie)
        |> post(~p"/api/auth/refresh")

      assert json_response(retry_conn, 401)
    end
  end

  describe "password reset" do
    test "request always responds 204, regardless of whether the email exists", %{conn: conn} do
      user_fixture()

      conn1 = post(conn, ~p"/api/auth/password_resets", %{"email" => "parent@example.com"})
      assert response(conn1, 204)

      conn2 = post(conn, ~p"/api/auth/password_resets", %{"email" => "nobody@example.com"})
      assert response(conn2, 204)

      assert_received {:email, email}
      assert email.to == [{"", "parent@example.com"}]
    end

    test "reset with a valid token updates the password and logs the user in", %{conn: conn} do
      user_fixture()

      post(conn, ~p"/api/auth/password_resets", %{"email" => "parent@example.com"})
      assert_received {:email, email}
      [_, token] = Regex.run(~r{reset-password/([^\s]+)}, email.text_body)

      reset_conn =
        put(conn, ~p"/api/auth/password_resets/#{token}", %{
          "password" => "newpassword123",
          "password_confirmation" => "newpassword123"
        })

      assert %{"data" => %{"user" => %{"email" => "parent@example.com"}, "access_token" => _}} =
               json_response(reset_conn, 200)

      login_conn =
        post(conn, ~p"/api/auth/login", %{"email" => "parent@example.com", "password" => "newpassword123"})

      assert json_response(login_conn, 200)
    end

    test "reset with an invalid token is rejected", %{conn: conn} do
      conn =
        put(conn, ~p"/api/auth/password_resets/bogus", %{
          "password" => "newpassword123",
          "password_confirmation" => "newpassword123"
        })

      assert %{"errors" => %{"code" => "invalid_token"}} = json_response(conn, 422)
    end
  end
end
