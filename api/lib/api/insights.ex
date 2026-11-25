defmodule Api.Insights do
  @moduledoc """
  "Time since last X" is already in `Api.Feed.summary/1`; this adds the two
  further things Step 9 asks for per baby per metric: a rolling 7-day daily
  average, and whether the gap since the last log is unusually long given
  that average.

  `compute_for_baby/1` is a pure read used directly by `Api.Feed.summary/1`
  so the feed's insight chips are always as fresh as the rest of the
  summary (no separate staleness class to worry about, the same way the
  rest of the app avoids it). `recompute_and_store_all!/0` is the Oban-job
  side: it persists the same computation into the `insights` table on a
  schedule, independent of anyone having the app open, since that's what a
  future reminder notification (Step 10, once push delivery exists) would
  need to query without a request in flight.

  A metric only gets a `long_gap` baseline once it has at least
  `@min_avg_per_day_for_baseline` logs/day over the last 7 days — a single
  stray log doesn't establish a pattern, and a metric with no recent
  history at all (e.g. breastfeeding for a formula-fed baby) should stay
  quiet rather than flag a "gap" that was never really a routine.
  """

  import Ecto.Query, warn: false

  alias Api.Babies.Baby
  alias Api.BottleFeedings.BottleFeeding
  alias Api.BreastfeedingLogs.BreastfeedingLog
  alias Api.DiaperLogs.DiaperLog
  alias Api.Insights.Insight
  alias Api.Repo

  @rolling_window_days 7
  @min_avg_per_day_for_baseline 0.5
  @gap_multiplier 2
  @min_gap_minutes 60

  @metrics %{diaper: DiaperLog, bottle: BottleFeeding, breastfeeding: BreastfeedingLog}

  def compute_for_baby(%Baby{} = baby) do
    now = DateTime.utc_now()
    window_start = DateTime.add(now, -@rolling_window_days * 24 * 60 * 60, :second)

    Map.new(@metrics, fn {metric, schema} ->
      {metric, compute_metric(schema, baby.id, window_start, now)}
    end)
  end

  defp compute_metric(schema, baby_id, window_start, now) do
    count_last_7_days =
      schema
      |> where([log], log.baby_id == ^baby_id and log.logged_at >= ^window_start)
      |> select([log], count(log.id))
      |> Repo.one()

    last_logged_at =
      schema
      |> where(baby_id: ^baby_id)
      |> order_by(desc: :logged_at)
      |> limit(1)
      |> select([log], log.logged_at)
      |> Repo.one()

    avg_per_day_7d = count_last_7_days / @rolling_window_days

    %{
      avg_per_day_7d: avg_per_day_7d,
      last_logged_at: last_logged_at,
      long_gap: long_gap?(avg_per_day_7d, last_logged_at, now)
    }
  end

  defp long_gap?(avg_per_day_7d, last_logged_at, now)
       when avg_per_day_7d >= @min_avg_per_day_for_baseline and not is_nil(last_logged_at) do
    expected_interval_minutes = 24 * 60 / avg_per_day_7d
    minutes_since_last = DateTime.diff(now, last_logged_at, :second) / 60

    minutes_since_last > max(expected_interval_minutes * @gap_multiplier, @min_gap_minutes)
  end

  defp long_gap?(_avg_per_day_7d, _last_logged_at, _now), do: false

  @doc "Recomputes and upserts stored insights for every baby. Called by `Api.Insights.ComputeInsightsWorker`."
  def recompute_and_store_all! do
    Baby
    |> Repo.all()
    |> Enum.each(&upsert_for_baby!/1)
  end

  def upsert_for_baby!(%Baby{} = baby) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    baby
    |> compute_for_baby()
    |> Enum.each(fn {metric, %{avg_per_day_7d: avg, long_gap: long_gap}} ->
      %Insight{}
      |> Insight.changeset(%{
        baby_id: baby.id,
        metric: Atom.to_string(metric),
        avg_per_day_7d: avg,
        long_gap: long_gap,
        computed_at: now
      })
      |> Repo.insert!(
        on_conflict: {:replace, [:avg_per_day_7d, :long_gap, :computed_at, :updated_at]},
        conflict_target: [:baby_id, :metric]
      )
    end)
  end

  @doc "Stored insights currently flagged `long_gap`, for a future reminder consumer."
  def list_long_gap do
    Insight
    |> where(long_gap: true)
    |> Repo.all()
  end
end
