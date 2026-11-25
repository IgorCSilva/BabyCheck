defmodule Api.InsightsTest do
  use Api.DataCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.DiaperLogs
  alias Api.Insights
  alias Api.Insights.Insight
  alias Api.Insights.ComputeInsightsWorker
  alias Api.Repo

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

  defp ago(amount, unit), do: DateTime.add(DateTime.utc_now(), -amount, unit)

  describe "compute_for_baby/1" do
    test "avg_per_day_7d only counts logs within the rolling 7-day window" do
      baby = baby_fixture(user_fixture())

      for n <- [1, 2, 3], do: diaper_fixture(baby, ago(n, :day))
      diaper_fixture(baby, ago(10, :day))
      diaper_fixture(baby, ago(20, :day))

      assert %{diaper: %{avg_per_day_7d: avg}} = Insights.compute_for_baby(baby)
      assert_in_delta avg, 3 / 7, 0.0001
    end

    test "long_gap is false without enough history to establish a baseline" do
      baby = baby_fixture(user_fixture())
      diaper_fixture(baby, ago(6, :day))

      assert %{diaper: %{long_gap: false}} = Insights.compute_for_baby(baby)
    end

    test "long_gap is false when there has never been a log for that metric" do
      baby = baby_fixture(user_fixture())

      assert %{diaper: %{avg_per_day_7d: avg, long_gap: false, last_logged_at: nil}} =
               Insights.compute_for_baby(baby)

      assert avg == 0.0
    end

    test "long_gap is true once the gap is more than double the expected interval" do
      baby = baby_fixture(user_fixture())
      # 5 logs/7 days => ~33.6h expected interval; the most recent one was
      # 72h ago, well past double that.
      for hours_ago <- [72, 96, 120, 144, 160], do: diaper_fixture(baby, ago(hours_ago, :hour))

      assert %{diaper: %{avg_per_day_7d: avg, long_gap: true}} = Insights.compute_for_baby(baby)
      assert avg >= 0.5
    end

    test "long_gap is false while the gap is within double the expected interval" do
      baby = baby_fixture(user_fixture())
      # Roughly one log/day => ~24h expected interval; the most recent one
      # was only 20h ago, well within double that.
      for hours_ago <- [20, 44, 68, 92, 116, 140, 164], do: diaper_fixture(baby, ago(hours_ago, :hour))

      assert %{diaper: %{long_gap: false}} = Insights.compute_for_baby(baby)
    end
  end

  describe "upsert_for_baby!/1 and recompute_and_store_all!/0" do
    test "stores exactly one insight row per metric, and upserts on recompute instead of duplicating" do
      baby = baby_fixture(user_fixture())
      diaper_fixture(baby, ago(1, :day))

      Insights.upsert_for_baby!(baby)
      assert Repo.aggregate(Insight, :count) == 3

      diaper_fixture(baby, ago(0, :day))
      Insights.upsert_for_baby!(baby)

      assert Repo.aggregate(Insight, :count) == 3
      stored = Repo.get_by!(Insight, baby_id: baby.id, metric: "diaper")
      assert_in_delta stored.avg_per_day_7d, 2 / 7, 0.0001
    end

    test "recompute_and_store_all! covers every baby, not just one" do
      user = user_fixture()
      riley = baby_fixture(user, %{name: "Riley"})
      sam = baby_fixture(user, %{name: "Sam", theme_color: "#9DC8E8"})

      Insights.recompute_and_store_all!()

      assert Repo.aggregate(Insight, :count) == 6
      assert Repo.get_by(Insight, baby_id: riley.id, metric: "bottle")
      assert Repo.get_by(Insight, baby_id: sam.id, metric: "bottle")
    end
  end

  describe "list_long_gap/0" do
    test "returns only stored insights currently flagged long_gap" do
      baby = baby_fixture(user_fixture())
      for hours_ago <- [72, 96, 120, 144, 160], do: diaper_fixture(baby, ago(hours_ago, :hour))

      Insights.upsert_for_baby!(baby)

      assert [%Insight{metric: "diaper", baby_id: baby_id}] = Insights.list_long_gap()
      assert baby_id == baby.id
    end
  end

  describe "ComputeInsightsWorker.perform/1" do
    test "recomputes and stores insights for every baby" do
      baby = baby_fixture(user_fixture())
      diaper_fixture(baby, ago(1, :day))

      assert :ok = ComputeInsightsWorker.perform(%Oban.Job{})
      assert Repo.aggregate(Insight, :count) == 3
    end
  end
end
