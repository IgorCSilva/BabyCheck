defmodule Api.Feed do
  @moduledoc """
  Merges diaper logs, bottle feedings, and breastfeeding logs across every
  baby an account owns into a single chronological feed, plus a per-baby
  "time since last" summary for the three metrics.

  `list_entries/2` fetches up to `limit` rows from each of the three tables
  (each already ordered `logged_at desc`) and merges them client-side: the
  true global top-`limit` across any set of sorted streams can never need
  more than `limit` rows from any single stream, so this is exact, not an
  approximation. Pagination is cursor-based on `logged_at` (`before`) rather
  than offset-based, so new logs landing while a user scrolls never shift
  already-seen pages.
  """

  import Ecto.Query, warn: false

  alias Api.Repo
  alias Api.Accounts.User
  alias Api.Babies.Baby
  alias Api.BottleFeedings.BottleFeeding
  alias Api.BreastfeedingLogs.BreastfeedingLog
  alias Api.DiaperLogs.DiaperLog
  alias Api.Insights

  def list_entries(%User{} = user, opts \\ %{}) do
    limit = Map.get(opts, :limit, 20)
    before = Map.get(opts, :before)
    babies_by_id = babies_by_id(user)
    baby_ids = Map.keys(babies_by_id)

    [
      fetch_stream(DiaperLog, baby_ids, before, limit, "diaper", babies_by_id),
      fetch_stream(BottleFeeding, baby_ids, before, limit, "bottle", babies_by_id),
      fetch_stream(BreastfeedingLog, baby_ids, before, limit, "breastfeeding", babies_by_id)
    ]
    |> Enum.concat()
    |> Enum.sort_by(& &1.logged_at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  def summary(%User{} = user) do
    user
    |> babies_by_id()
    |> Map.values()
    |> Enum.sort_by(& &1.id)
    |> Enum.map(fn baby ->
      insights = Insights.compute_for_baby(baby)

      %{
        baby_id: baby.id,
        baby_name: baby.name,
        baby_theme_color: baby.theme_color,
        diaper_last_logged_at: last_logged_at(DiaperLog, baby.id),
        bottle_last_logged_at: last_logged_at(BottleFeeding, baby.id),
        breastfeeding_last_logged_at: last_logged_at(BreastfeedingLog, baby.id),
        diaper_avg_per_day_7d: insights.diaper.avg_per_day_7d,
        bottle_avg_per_day_7d: insights.bottle.avg_per_day_7d,
        breastfeeding_avg_per_day_7d: insights.breastfeeding.avg_per_day_7d,
        diaper_long_gap: insights.diaper.long_gap,
        bottle_long_gap: insights.bottle.long_gap,
        breastfeeding_long_gap: insights.breastfeeding.long_gap
      }
    end)
  end

  defp babies_by_id(%User{} = user) do
    Baby
    |> where(user_id: ^user.id)
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp fetch_stream(_schema, [], _before, _limit, _type, _babies_by_id), do: []

  defp fetch_stream(schema, baby_ids, before, limit, type, babies_by_id) do
    schema
    |> where([log], log.baby_id in ^baby_ids)
    |> filter_before(before)
    |> order_by(desc: :logged_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.map(&build_entry(&1, type, babies_by_id))
  end

  defp filter_before(query, nil), do: query
  defp filter_before(query, before), do: where(query, [log], log.logged_at < ^before)

  defp build_entry(log, type, babies_by_id) do
    baby = babies_by_id[log.baby_id]

    %{
      type: type,
      id: log.id,
      baby_id: log.baby_id,
      baby_name: baby.name,
      baby_theme_color: baby.theme_color,
      logged_at: log.logged_at,
      peed: Map.get(log, :peed, nil),
      pooped: Map.get(log, :pooped, nil),
      water_ml: Map.get(log, :water_ml, nil),
      formula_g: Map.get(log, :formula_g, nil)
    }
  end

  defp last_logged_at(schema, baby_id) do
    schema
    |> where(baby_id: ^baby_id)
    |> order_by(desc: :logged_at)
    |> limit(1)
    |> select([log], log.logged_at)
    |> Repo.one()
  end
end
