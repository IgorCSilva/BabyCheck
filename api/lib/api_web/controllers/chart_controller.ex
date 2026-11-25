defmodule ApiWeb.ChartController do
  use ApiWeb, :controller

  alias Api.Babies
  alias Api.Babies.Baby
  alias Api.Charts

  action_fallback ApiWeb.FallbackController

  @default_days 6

  def index(conn, %{"baby_id" => baby_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, baby_id) do
      {from, to} = parse_range(params)
      render(conn, :index, charts: Charts.daily_counts(baby, from, to))
    else
      nil -> {:error, :not_found}
    end
  end

  # A missing or malformed range just falls back to the last 7 days rather
  # than a user-facing validation error, matching the feed endpoint's
  # tolerance of bad query params.
  defp parse_range(params) do
    with %DateTime{} = from <- parse_datetime(params["from"]),
         %DateTime{} = to <- parse_datetime(params["to"]),
         :lt_or_eq <- compare(from, to) do
      {from, to}
    else
      _ -> default_range()
    end
  end

  defp compare(from, to) do
    if Date.compare(DateTime.to_date(from), DateTime.to_date(to)) in [:lt, :eq],
      do: :lt_or_eq,
      else: :gt
  end

  defp default_range do
    to = DateTime.utc_now()
    from = DateTime.add(to, -@default_days, :day)
    {from, to}
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end
end
