defmodule Api.AccountsTest do
  use Api.DataCase, async: true

  alias Api.Accounts
  alias Api.Accounts.User

  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "parent#{System.unique_integer()}@example.com",
        password: "supersecret123",
        password_confirmation: "supersecret123"
      })
      |> Accounts.register_user()

    user
  end

  describe "register_user/1" do
    test "creates a user with a hashed password" do
      assert {:ok, %User{} = user} =
               Accounts.register_user(%{
                 email: "Parent@Example.com",
                 password: "supersecret123",
                 password_confirmation: "supersecret123"
               })

      assert user.email == "parent@example.com"
      assert user.hashed_password != "supersecret123"
      assert Bcrypt.verify_pass("supersecret123", user.hashed_password)
    end

    test "requires a valid email" do
      assert {:error, changeset} =
               Accounts.register_user(%{
                 email: "not-an-email",
                 password: "supersecret123",
                 password_confirmation: "supersecret123"
               })

      assert "must be a valid email" in errors_on(changeset).email
    end

    test "requires a password confirmation match" do
      assert {:error, changeset} =
               Accounts.register_user(%{
                 email: "parent@example.com",
                 password: "supersecret123",
                 password_confirmation: "nope"
               })

      assert "does not match password" in errors_on(changeset).password_confirmation
    end

    test "requires a password of at least 8 characters" do
      assert {:error, changeset} =
               Accounts.register_user(%{
                 email: "parent@example.com",
                 password: "short",
                 password_confirmation: "short"
               })

      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "rejects a duplicate email" do
      user_fixture(%{email: "taken@example.com"})

      assert {:error, changeset} =
               Accounts.register_user(%{
                 email: "taken@example.com",
                 password: "supersecret123",
                 password_confirmation: "supersecret123"
               })

      assert "has already been taken" in errors_on(changeset).email
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "returns the user on correct credentials" do
      user = user_fixture(%{email: "parent@example.com", password: "supersecret123"})

      assert %User{id: id} =
               Accounts.get_user_by_email_and_password("parent@example.com", "supersecret123")

      assert id == user.id
    end

    test "is case-insensitive on email" do
      user = user_fixture(%{email: "parent@example.com", password: "supersecret123"})

      assert %User{id: id} =
               Accounts.get_user_by_email_and_password("Parent@Example.com", "supersecret123")

      assert id == user.id
    end

    test "returns nil on wrong password" do
      user_fixture(%{email: "parent@example.com", password: "supersecret123"})
      assert Accounts.get_user_by_email_and_password("parent@example.com", "wrongpass") == nil
    end

    test "returns nil for an unknown email" do
      assert Accounts.get_user_by_email_and_password("nobody@example.com", "whatever1") == nil
    end
  end

  describe "sessions" do
    test "create_session/2 issues an access token and a raw refresh token" do
      user = user_fixture()
      assert {:ok, access_token, raw_refresh_token} = Accounts.create_session(user, true)
      assert is_binary(access_token)
      assert is_binary(raw_refresh_token)
      assert {:ok, _claims} = Api.Guardian.decode_and_verify(access_token)
    end

    test "refresh_session/1 rotates the refresh token and preserves remember_me" do
      user = user_fixture()
      {:ok, _access_token, raw_refresh_token} = Accounts.create_session(user, true)

      assert {:ok, {refreshed_user, new_access_token, new_raw_refresh_token, true}} =
               Accounts.refresh_session(raw_refresh_token)

      assert refreshed_user.id == user.id
      assert new_raw_refresh_token != raw_refresh_token
      assert {:ok, _claims} = Api.Guardian.decode_and_verify(new_access_token)

      # the old token was rotated out and can't be reused
      assert Accounts.refresh_session(raw_refresh_token) == {:error, :invalid_or_expired}
    end

    test "refresh_session/1 rejects an unknown token" do
      assert Accounts.refresh_session("not-a-real-token") == {:error, :invalid_or_expired}
    end

    test "revoke_refresh_token/1 invalidates the token" do
      user = user_fixture()
      {:ok, _access_token, raw_refresh_token} = Accounts.create_session(user, false)

      assert Accounts.revoke_refresh_token(raw_refresh_token) == :ok
      assert Accounts.refresh_session(raw_refresh_token) == {:error, :invalid_or_expired}
    end
  end

  describe "password reset" do
    test "deliver_user_reset_password_instructions/2 emails a working reset link" do
      user = user_fixture(%{email: "parent@example.com"})

      Accounts.deliver_user_reset_password_instructions(user, fn token ->
        "http://localhost:3000/reset-password/#{token}"
      end)

      assert_received {:email, email}
      assert email.to == [{"", "parent@example.com"}]
      assert email.text_body =~ "http://localhost:3000/reset-password/"

      [_, token] = Regex.run(~r{reset-password/([^\s]+)}, email.text_body)
      assert Accounts.get_user_by_reset_password_token(token).id == user.id
    end

    test "get_user_by_reset_password_token/1 returns nil for an invalid token" do
      assert Accounts.get_user_by_reset_password_token("bogus") == nil
    end

    test "reset_user_password/2 updates the password and revokes refresh tokens" do
      user = user_fixture(%{password: "supersecret123"})
      {:ok, _access_token, raw_refresh_token} = Accounts.create_session(user, true)

      assert {:ok, updated_user} =
               Accounts.reset_user_password(user, %{
                 "password" => "newpassword123",
                 "password_confirmation" => "newpassword123"
               })

      assert Bcrypt.verify_pass("newpassword123", updated_user.hashed_password)
      assert Accounts.get_user_by_email_and_password(user.email, "supersecret123") == nil
      assert Accounts.refresh_session(raw_refresh_token) == {:error, :invalid_or_expired}
    end
  end
end
