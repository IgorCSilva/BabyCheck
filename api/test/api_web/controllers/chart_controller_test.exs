defmodule ApiWeb.ChartControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.BottleFeedings
  alias Api.BreastfeedingLogs
  alias Api.DiaperLogs

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

  defp authed_conn(conn, user) do
    {:ok, access_token, _refresh} = Accounts.create_session(user, false)
    put_req_header(conn, "authorization", "Bearer #{access_token}")
  end

  describe "GET /api/babies/:baby_id/charts" do
    test "requires authentication", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn = get(conn, ~p"/api/babies/#{baby.id}/charts")
      assert json_response(conn, 401)
    end

    test "returns zero-filled daily counts per metric over the given range", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      {:ok, _} = DiaperLogs.create_log(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})
      {:ok, _} = DiaperLogs.create_log(baby, %{logged_at: ~U[2026-11-20 20:00:00Z]})
      {:ok, _} = BottleFeedings.create_feeding(baby, %{logged_at: ~U[2026-11-21 08:00:00Z]})
      {:ok, _} = BreastfeedingLogs.create_log(baby, %{logged_at: ~U[2026-11-22 08:00:00Z]})

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/charts", %{
          "from" => "2026-11-20T00:00:00Z",
          "to" => "2026-11-22T23:59:59Z"
        })

      assert %{"data" => data} = json_response(conn, 200)

      assert data["diaper"] == [
               %{"date" => "2026-11-20", "count" => 2},
               %{"date" => "2026-11-21", "count" => 0},
               %{"date" => "2026-11-22", "count" => 0}
             ]

      assert data["bottle"] == [
               %{"date" => "2026-11-20", "count" => 0},
               %{"date" => "2026-11-21", "count" => 1},
               %{"date" => "2026-11-22", "count" => 0}
             ]

      assert data["breastfeeding"] == [
               %{"date" => "2026-11-20", "count" => 0},
               %{"date" => "2026-11-21", "count" => 0},
               %{"date" => "2026-11-22", "count" => 1}
             ]
    end

    test "excludes another user's baby's logs", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      other_baby = baby_fixture(user_fixture())

      {:ok, _} = DiaperLogs.create_log(other_baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/charts", %{
          "from" => "2026-11-20T00:00:00Z",
          "to" => "2026-11-20T23:59:59Z"
        })

      assert %{"data" => %{"diaper" => [%{"count" => 0}]}} = json_response(conn, 200)
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{other_baby.id}/charts")

      assert json_response(conn, 404)
    end

    test "falls back to the last 7 days when from/to are missing", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      {:ok, _} = DiaperLogs.create_log(baby, %{logged_at: DateTime.utc_now()})

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/charts")

      assert %{"data" => %{"diaper" => diaper}} = json_response(conn, 200)
      assert length(diaper) == 7
      assert Enum.reduce(diaper, 0, fn %{"count" => count}, acc -> acc + count end) == 1
    end

    test "falls back to the default range when from/to are malformed", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/charts", %{"from" => "not-a-date", "to" => "also-not"})

      assert %{"data" => %{"diaper" => diaper}} = json_response(conn, 200)
      assert length(diaper) == 7
    end
  end
end
