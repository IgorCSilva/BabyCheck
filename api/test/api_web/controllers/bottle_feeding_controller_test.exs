defmodule ApiWeb.BottleFeedingControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.BottleFeedings

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

  defp baby_fixture(user, attrs \\ %{}) do
    {:ok, baby} =
      attrs
      |> Enum.into(%{name: "Riley", theme_color: "#F5A9B8"})
      |> then(&Babies.create_baby(user, &1))

    baby
  end

  defp feeding_fixture(baby, attrs \\ %{}) do
    {:ok, feeding} =
      attrs
      |> Enum.into(%{logged_at: ~U[2026-11-20 08:00:00Z]})
      |> then(&BottleFeedings.create_feeding(baby, &1))

    feeding
  end

  defp authed_conn(conn, user) do
    {:ok, access_token, _refresh} = Accounts.create_session(user, false)
    put_req_header(conn, "authorization", "Bearer #{access_token}")
  end

  describe "GET /api/babies/:baby_id/bottle_feedings" do
    test "requires authentication", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn = get(conn, ~p"/api/babies/#{baby.id}/bottle_feedings")
      assert json_response(conn, 401)
    end

    test "lists only the given baby's feedings", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      other_baby = baby_fixture(user, %{name: "Sam", theme_color: "#9DC8E8"})
      feeding = feeding_fixture(baby)
      feeding_fixture(other_baby)

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/bottle_feedings")

      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == feeding.id
    end

    test "filters by from/to", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      feeding_fixture(baby, %{logged_at: ~U[2026-11-19 08:00:00Z]})
      in_range = feeding_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/bottle_feedings", %{
          "from" => "2026-11-20T00:00:00Z",
          "to" => "2026-11-20T23:59:59Z"
        })

      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == in_range.id
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{other_baby.id}/bottle_feedings")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/babies/:baby_id/bottle_feedings" do
    test "creates a feeding with explicit fields", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies/#{baby.id}/bottle_feedings", %{
          "logged_at" => "2026-11-20T08:00:00Z",
          "water_ml" => 45,
          "formula_g" => 15
        })

      assert %{"data" => %{"id" => id, "water_ml" => 45, "formula_g" => 15}} =
               json_response(conn, 201)

      assert is_integer(id)
    end

    test "defaults logged_at, water_ml, and formula_g for a one-tap log", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies/#{baby.id}/bottle_feedings", %{})

      assert %{"data" => %{"logged_at" => logged_at, "water_ml" => 30, "formula_g" => 10}} =
               json_response(conn, 201)

      assert is_binary(logged_at)
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies/#{other_baby.id}/bottle_feedings", %{})

      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/bottle_feedings/:id" do
    test "updates a feeding owned by the current user", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      feeding = feeding_fixture(baby)

      conn =
        conn
        |> authed_conn(user)
        |> put(~p"/api/bottle_feedings/#{feeding.id}", %{
          "logged_at" => "2026-11-21T09:30:00Z",
          "water_ml" => 50,
          "formula_g" => 18
        })

      assert %{"data" => %{"water_ml" => 50, "formula_g" => 18}} = json_response(conn, 200)
    end

    test "returns 404 for another user's feeding", %{conn: conn} do
      user = user_fixture()
      other_feeding = feeding_fixture(baby_fixture(user_fixture()))

      conn =
        conn
        |> authed_conn(user)
        |> put(~p"/api/bottle_feedings/#{other_feeding.id}", %{"water_ml" => 50})

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/bottle_feedings/:id" do
    test "removes a feeding owned by the current user", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      feeding = feeding_fixture(baby)

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/bottle_feedings/#{feeding.id}")

      assert response(conn, 204)
      assert BottleFeedings.list_feedings(baby) == []
    end

    test "returns 404 for another user's feeding", %{conn: conn} do
      user = user_fixture()
      other_feeding = feeding_fixture(baby_fixture(user_fixture()))

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/bottle_feedings/#{other_feeding.id}")

      assert json_response(conn, 404)
    end
  end
end
