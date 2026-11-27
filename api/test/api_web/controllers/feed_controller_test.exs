defmodule ApiWeb.FeedControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.BottleFeedings
  alias Api.BreastfeedingLogs
  alias Api.DiaperLogs
  alias Api.GrowthMeasurements

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

  defp diaper_fixture(baby, attrs \\ %{}) do
    {:ok, log} =
      attrs
      |> Enum.into(%{logged_at: ~U[2026-11-20 08:00:00Z]})
      |> then(&DiaperLogs.create_log(baby, &1))

    log
  end

  defp bottle_fixture(baby, attrs \\ %{}) do
    {:ok, feeding} =
      attrs
      |> Enum.into(%{logged_at: ~U[2026-11-20 08:00:00Z]})
      |> then(&BottleFeedings.create_feeding(baby, &1))

    feeding
  end

  defp breastfeeding_fixture(baby, attrs \\ %{}) do
    {:ok, log} =
      attrs
      |> Enum.into(%{logged_at: ~U[2026-11-20 08:00:00Z]})
      |> then(&BreastfeedingLogs.create_log(baby, &1))

    log
  end

  defp growth_fixture(baby, attrs \\ %{}) do
    {:ok, measurement} =
      attrs
      |> Enum.into(%{weight_kg: 4.2, measured_at: ~D[2026-11-20]})
      |> then(&GrowthMeasurements.create_measurement(baby, &1))

    measurement
  end

  defp authed_conn(conn, user) do
    {:ok, access_token, _refresh} = Accounts.create_session(user, false)
    put_req_header(conn, "authorization", "Bearer #{access_token}")
  end

  describe "GET /api/feed" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/feed")
      assert json_response(conn, 401)
    end

    test "returns entries across all of the user's babies, newest first", %{conn: conn} do
      user = user_fixture()
      riley = baby_fixture(user, %{name: "Riley"})
      sam = baby_fixture(user, %{name: "Sam", theme_color: "#9DC8E8"})

      diaper = diaper_fixture(riley, %{logged_at: ~U[2026-11-20 08:00:00Z]})
      bottle = bottle_fixture(sam, %{logged_at: ~U[2026-11-20 09:00:00Z], water_ml: 60, formula_g: 15})

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/feed")

      assert %{"data" => [first, second]} = json_response(conn, 200)

      assert first["type"] == "bottle"
      assert first["id"] == bottle.id
      assert first["baby_name"] == "Sam"
      assert first["water_ml"] == 60
      assert first["formula_g"] == 15

      assert second["type"] == "diaper"
      assert second["id"] == diaper.id
      assert second["baby_name"] == "Riley"
    end

    test "includes growth measurements with their weight/height", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      growth = growth_fixture(baby, %{weight_kg: 4.2, height_cm: 55.0, measured_at: ~D[2026-11-21]})

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/feed")

      assert %{"data" => [entry]} = json_response(conn, 200)
      assert entry["type"] == "growth"
      assert entry["id"] == growth.id
      assert entry["weight_kg"] == 4.2
      assert entry["height_cm"] == 55.0
    end

    test "excludes another user's entries", %{conn: conn} do
      user = user_fixture()
      diaper_fixture(baby_fixture(user_fixture()))

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/feed")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "paginates with the before cursor", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      older = diaper_fixture(baby, %{logged_at: ~U[2026-11-19 08:00:00Z]})
      newer = diaper_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})

      conn = conn |> authed_conn(user) |> get(~p"/api/feed", %{"limit" => "1"})
      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == newer.id

      conn =
        build_conn()
        |> authed_conn(user)
        |> get(~p"/api/feed", %{"before" => newer.logged_at |> DateTime.to_iso8601()})

      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == older.id
    end
  end

  describe "GET /api/feed/summary" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/feed/summary")
      assert json_response(conn, 401)
    end

    test "returns one row per baby with the last logged_at per metric", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user, %{name: "Riley", theme_color: "#F5A9B8"})
      breastfeeding_fixture(baby, %{logged_at: ~U[2026-11-20 10:00:00Z]})

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/feed/summary")

      assert %{
               "data" => [
                 %{
                   "baby_id" => baby_id,
                   "baby_name" => "Riley",
                   "baby_theme_color" => "#F5A9B8",
                   "diaper_last_logged_at" => nil,
                   "bottle_last_logged_at" => nil,
                   "breastfeeding_last_logged_at" => "2026-11-20T10:00:00Z"
                 }
               ]
             } = json_response(conn, 200)

      assert baby_id == baby.id
    end

    test "includes a rolling 7-day average and gap flag per metric", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      now = DateTime.utc_now()

      for hours_ago <- [72, 96, 120, 144, 160] do
        diaper_fixture(baby, %{logged_at: DateTime.add(now, -hours_ago * 3600, :second)})
      end

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/feed/summary")

      assert %{
               "data" => [
                 %{
                   "diaper_avg_per_day_7d" => diaper_avg,
                   "diaper_long_gap" => true,
                   "bottle_avg_per_day_7d" => bottle_avg,
                   "bottle_long_gap" => false,
                   "breastfeeding_avg_per_day_7d" => breastfeeding_avg,
                   "breastfeeding_long_gap" => false
                 }
               ]
             } = json_response(conn, 200)

      assert diaper_avg >= 0.5
      assert bottle_avg == 0.0
      assert breastfeeding_avg == 0.0
    end
  end
end
