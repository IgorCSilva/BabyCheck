defmodule Api.Charts do
  @moduledoc """
  Daily aggregate counts per metric for a single baby, over an inclusive
  date range. Every day in the range is present in each metric's series
  (zero-filled when nothing was logged that day) so the frontend can chart a
  continuous axis without having to patch in missing days itself.
  """

  import Ecto.Query, warn: false

  alias Api.Repo
  alias Api.Babies.Baby
  alias Api.BottleFeedings.BottleFeeding
  alias Api.BreastfeedingLogs.BreastfeedingLog
  alias Api.DiaperLogs.DiaperLog

  def daily_counts(%Baby{} = baby, %DateTime{} = from, %DateTime{} = to) do
    %{
      diaper: counts_for(DiaperLog, baby.id, from, to),
      bottle: counts_for(BottleFeeding, baby.id, from, to),
      breastfeeding: counts_for(BreastfeedingLog, baby.id, from, to)
    }
  end

  defp counts_for(schema, baby_id, from, to) do
    counts_by_date =
      schema
      |> where([log], log.baby_id == ^baby_id)
      |> where([log], log.logged_at >= ^from and log.logged_at <= ^to)
      |> group_by([log], fragment("date(?)", log.logged_at))
      |> select([log], {fragment("date(?)", log.logged_at), count(log.id)})
      |> Repo.all()
      |> Map.new()

    from_date = DateTime.to_date(from)
    to_date = DateTime.to_date(to)

    if Date.compare(from_date, to_date) == :gt do
      []
    else
      Date.range(from_date, to_date)
      |> Enum.map(fn date -> %{date: date, count: Map.get(counts_by_date, date, 0)} end)
    end
  end
end
