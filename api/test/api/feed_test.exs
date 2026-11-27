defmodule Api.FeedTest do
  use Api.DataCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.BottleFeedings
  alias Api.BreastfeedingLogs
  alias Api.DiaperLogs
  alias Api.Feed
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

  describe "list_entries/2" do
    test "merges all three metrics across every one of the user's babies, newest first" do
      user = user_fixture()
      riley = baby_fixture(user, %{name: "Riley"})
      sam = baby_fixture(user, %{name: "Sam", theme_color: "#9DC8E8"})

      diaper = diaper_fixture(riley, %{logged_at: ~U[2026-11-20 08:00:00Z]})
      bottle = bottle_fixture(sam, %{logged_at: ~U[2026-11-20 09:00:00Z]})
      breastfeeding = breastfeeding_fixture(riley, %{logged_at: ~U[2026-11-20 10:00:00Z]})

      entries = Feed.list_entries(user)

      assert [
               %{type: "breastfeeding", id: id1},
               %{type: "bottle", id: id2},
               %{type: "diaper", id: id3}
             ] = entries

      assert id1 == breastfeeding.id
      assert id2 == bottle.id
      assert id3 == diaper.id
    end

    test "excludes another user's babies entirely" do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())
      diaper_fixture(other_baby)

      assert Feed.list_entries(user) == []
    end

    test "includes each entry's baby name and theme color" do
      user = user_fixture()
      baby = baby_fixture(user, %{name: "Riley", theme_color: "#F5A9B8"})
      diaper_fixture(baby)

      assert [%{baby_name: "Riley", baby_theme_color: "#F5A9B8"}] = Feed.list_entries(user)
    end

    test "includes bottle feeding amounts and diaper flags, nil for the other metric's fields" do
      user = user_fixture()
      baby = baby_fixture(user)
      bottle_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z], water_ml: 60, formula_g: 15})
      diaper_fixture(baby, %{logged_at: ~U[2026-11-19 08:00:00Z], peed: true, pooped: false})

      assert [
               %{type: "bottle", water_ml: 60, formula_g: 15, peed: nil, pooped: nil},
               %{type: "diaper", peed: true, pooped: false, water_ml: nil, formula_g: nil}
             ] = Feed.list_entries(user)
    end

    test "includes growth measurements alongside the three quick-log metrics" do
      user = user_fixture()
      baby = baby_fixture(user)

      diaper = diaper_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})
      growth = growth_fixture(baby, %{weight_kg: 4.2, height_cm: 55.0, measured_at: ~D[2026-11-21]})

      assert [
               %{type: "growth", id: growth_id, weight_kg: 4.2, height_cm: 55.0},
               %{type: "diaper", id: diaper_id, weight_kg: nil, height_cm: nil}
             ] = Feed.list_entries(user)

      assert growth_id == growth.id
      assert diaper_id == diaper.id
    end

    test "a growth measurement sorts by its date among same-day quick-logs" do
      user = user_fixture()
      baby = baby_fixture(user)

      growth_fixture(baby, %{measured_at: ~D[2026-11-20]})
      diaper_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})

      assert [%{type: "diaper"}, %{type: "growth"}] = Feed.list_entries(user)
    end

    test "respects the before cursor for growth measurements too" do
      user = user_fixture()
      baby = baby_fixture(user)
      older = growth_fixture(baby, %{measured_at: ~D[2026-11-10]})
      growth_fixture(baby, %{measured_at: ~D[2026-11-20]})

      entries = Feed.list_entries(user, %{before: ~U[2026-11-15 00:00:00Z]})

      assert [%{type: "growth", id: id}] = entries
      assert id == older.id
    end

    test "respects the before cursor" do
      user = user_fixture()
      baby = baby_fixture(user)
      older = diaper_fixture(baby, %{logged_at: ~U[2026-11-19 08:00:00Z]})
      diaper_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})

      entries = Feed.list_entries(user, %{before: ~U[2026-11-20 08:00:00Z]})

      assert [%{id: id}] = entries
      assert id == older.id
    end

    test "caps the page at the given limit, taking the globally most recent entries" do
      user = user_fixture()
      baby = baby_fixture(user)

      for day <- 1..5 do
        diaper_fixture(baby, %{logged_at: DateTime.new!(~D[2026-11-01], ~T[08:00:00], "Etc/UTC") |> DateTime.add(day, :day)})
      end

      entries = Feed.list_entries(user, %{limit: 2})

      assert length(entries) == 2
      assert [%{logged_at: first}, %{logged_at: second}] = entries
      assert DateTime.compare(first, second) == :gt
    end
  end

  describe "summary/1" do
    test "returns the most recent logged_at per metric per baby" do
      user = user_fixture()
      baby = baby_fixture(user)

      diaper_fixture(baby, %{logged_at: ~U[2026-11-18 08:00:00Z]})
      newest_diaper = diaper_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})
      bottle = bottle_fixture(baby, %{logged_at: ~U[2026-11-19 08:00:00Z]})

      assert [
               %{
                 baby_id: baby_id,
                 diaper_last_logged_at: diaper_last,
                 bottle_last_logged_at: bottle_last,
                 breastfeeding_last_logged_at: nil
               }
             ] = Feed.summary(user)

      assert baby_id == baby.id
      assert diaper_last == newest_diaper.logged_at
      assert bottle_last == bottle.logged_at
    end

    test "returns one entry per baby, even with no logs yet" do
      user = user_fixture()
      baby_fixture(user)

      assert [
               %{
                 diaper_last_logged_at: nil,
                 bottle_last_logged_at: nil,
                 breastfeeding_last_logged_at: nil
               }
             ] = Feed.summary(user)
    end

    test "excludes another user's babies" do
      user = user_fixture()
      baby_fixture(user_fixture())

      assert Feed.summary(user) == []
    end

    test "includes a rolling 7-day average and gap flag per metric" do
      user = user_fixture()
      baby = baby_fixture(user)
      now = DateTime.utc_now()

      for hours_ago <- [72, 96, 120, 144, 160] do
        diaper_fixture(baby, %{logged_at: DateTime.add(now, -hours_ago * 3600, :second)})
      end

      assert [
               %{
                 diaper_avg_per_day_7d: diaper_avg,
                 diaper_long_gap: true,
                 bottle_avg_per_day_7d: bottle_avg,
                 bottle_long_gap: false,
                 breastfeeding_avg_per_day_7d: breastfeeding_avg,
                 breastfeeding_long_gap: false
               }
             ] = Feed.summary(user)

      assert diaper_avg >= 0.5
      assert bottle_avg == 0.0
      assert breastfeeding_avg == 0.0
    end
  end
end
