defmodule Api.ChartsTest do
  use Api.DataCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.BottleFeedings
  alias Api.BreastfeedingLogs
  alias Api.Charts
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

  defp diaper_fixture(baby, logged_at) do
    {:ok, log} = DiaperLogs.create_log(baby, %{logged_at: logged_at})
    log
  end

  defp bottle_fixture(baby, logged_at) do
    {:ok, log} = BottleFeedings.create_feeding(baby, %{logged_at: logged_at})
    log
  end

  defp breastfeeding_fixture(baby, logged_at) do
    {:ok, log} = BreastfeedingLogs.create_log(baby, %{logged_at: logged_at})
    log
  end

  describe "daily_counts/3" do
    test "buckets each metric by day, zero-filling days with no logs" do
      baby = baby_fixture(user_fixture())

      diaper_fixture(baby, ~U[2026-11-20 08:00:00Z])
      diaper_fixture(baby, ~U[2026-11-20 20:00:00Z])
      diaper_fixture(baby, ~U[2026-11-22 08:00:00Z])
      bottle_fixture(baby, ~U[2026-11-21 08:00:00Z])

      result =
        Charts.daily_counts(baby, ~U[2026-11-20 00:00:00Z], ~U[2026-11-22 23:59:59Z])

      assert result.diaper == [
               %{date: ~D[2026-11-20], count: 2},
               %{date: ~D[2026-11-21], count: 0},
               %{date: ~D[2026-11-22], count: 1}
             ]

      assert result.bottle == [
               %{date: ~D[2026-11-20], count: 0},
               %{date: ~D[2026-11-21], count: 1},
               %{date: ~D[2026-11-22], count: 0}
             ]

      assert result.breastfeeding == [
               %{date: ~D[2026-11-20], count: 0},
               %{date: ~D[2026-11-21], count: 0},
               %{date: ~D[2026-11-22], count: 0}
             ]
    end

    test "excludes another baby's logs" do
      user = user_fixture()
      baby = baby_fixture(user)
      other_baby = baby_fixture(user, %{name: "Sam", theme_color: "#9DC8E8"})

      diaper_fixture(other_baby, ~U[2026-11-20 08:00:00Z])

      result = Charts.daily_counts(baby, ~U[2026-11-20 00:00:00Z], ~U[2026-11-20 23:59:59Z])

      assert result.diaper == [%{date: ~D[2026-11-20], count: 0}]
    end

    test "excludes logs outside the range" do
      baby = baby_fixture(user_fixture())

      diaper_fixture(baby, ~U[2026-11-19 23:59:00Z])
      diaper_fixture(baby, ~U[2026-11-23 00:01:00Z])
      in_range = diaper_fixture(baby, ~U[2026-11-20 08:00:00Z])

      result = Charts.daily_counts(baby, ~U[2026-11-20 00:00:00Z], ~U[2026-11-22 23:59:59Z])

      total = Enum.reduce(result.diaper, 0, fn %{count: count}, acc -> acc + count end)
      assert total == 1
      assert DateTime.compare(in_range.logged_at, ~U[2026-11-20 00:00:00Z]) in [:eq, :gt]
    end

    test "returns an empty list for a from date after the to date" do
      baby = baby_fixture(user_fixture())

      result = Charts.daily_counts(baby, ~U[2026-11-22 00:00:00Z], ~U[2026-11-20 23:59:59Z])

      assert result.diaper == []
      assert result.bottle == []
      assert result.breastfeeding == []
    end

    test "breastfeeding counts land in their own series" do
      baby = baby_fixture(user_fixture())
      breastfeeding_fixture(baby, ~U[2026-11-20 08:00:00Z])

      result = Charts.daily_counts(baby, ~U[2026-11-20 00:00:00Z], ~U[2026-11-20 23:59:59Z])

      assert result.breastfeeding == [%{date: ~D[2026-11-20], count: 1}]
      assert result.diaper == [%{date: ~D[2026-11-20], count: 0}]
      assert result.bottle == [%{date: ~D[2026-11-20], count: 0}]
    end
  end
end
