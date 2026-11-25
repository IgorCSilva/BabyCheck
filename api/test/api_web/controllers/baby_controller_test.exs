defmodule ApiWeb.BabyControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Api.Accounts
  alias Api.Babies

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

  defp authed_conn(conn, user) do
    {:ok, access_token, _refresh} = Accounts.create_session(user, false)
    put_req_header(conn, "authorization", "Bearer #{access_token}")
  end

  describe "GET /api/babies" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/babies")
      assert json_response(conn, 401)
    end

    test "lists only the current user's babies", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, _} = Babies.create_baby(user, %{name: "Riley", theme_color: "#F5A9B8"})
      {:ok, _} = Babies.create_baby(other_user, %{name: "Sam", theme_color: "#9DC8E8"})

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies")

      assert %{"data" => [%{"name" => "Riley", "theme_color" => "#F5A9B8"}]} =
               json_response(conn, 200)
    end
  end

  describe "POST /api/babies" do
    test "creates a baby for the current user", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies", %{"name" => "Riley", "theme_color" => "#F5A9B8"})

      assert %{"data" => %{"id" => id, "name" => "Riley", "theme_color" => "#F5A9B8"}} =
               json_response(conn, 201)

      assert is_integer(id)
    end

    test "rejects an invalid theme color", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies", %{"name" => "Riley", "theme_color" => "not-a-color"})

      assert %{"errors" => %{"theme_color" => _}} = json_response(conn, 422)
    end
  end

  describe "PUT /api/babies/:id" do
    test "updates a baby owned by the current user", %{conn: conn} do
      user = user_fixture()
      {:ok, baby} = Babies.create_baby(user, %{name: "Riley", theme_color: "#F5A9B8"})

      conn =
        conn
        |> authed_conn(user)
        |> put(~p"/api/babies/#{baby.id}", %{"name" => "Sam", "theme_color" => "#9DC8E8"})

      assert %{"data" => %{"name" => "Sam", "theme_color" => "#9DC8E8"}} = json_response(conn, 200)
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, baby} = Babies.create_baby(other_user, %{name: "Riley", theme_color: "#F5A9B8"})

      conn =
        conn
        |> authed_conn(user)
        |> put(~p"/api/babies/#{baby.id}", %{"name" => "Sam"})

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/babies/:id" do
    test "removes a baby owned by the current user", %{conn: conn} do
      user = user_fixture()
      {:ok, baby} = Babies.create_baby(user, %{name: "Riley", theme_color: "#F5A9B8"})

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/babies/#{baby.id}")

      assert response(conn, 204)
      assert Babies.list_babies(user) == []
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, baby} = Babies.create_baby(other_user, %{name: "Riley", theme_color: "#F5A9B8"})

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/babies/#{baby.id}")

      assert json_response(conn, 404)
    end
  end
end
