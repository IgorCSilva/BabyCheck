defmodule ApiWeb.FeedController do
  use ApiWeb, :controller

  alias Api.Feed

  action_fallback ApiWeb.FallbackController

  @default_limit 20
  @max_limit 100

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    opts = %{
      before: parse_datetime(params["before"]),
      limit: parse_limit(params["limit"])
    }

    render(conn, :index, entries: Feed.list_entries(user, opts))
  end

  def summary(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    render(conn, :summary, summary: Feed.summary(user))
  end

  # A malformed/missing cursor just means "start from the most recent
  # entry," the same tolerant handling the per-metric controllers use for
  # their from/to range filters.
  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp parse_limit(nil), do: @default_limit

  defp parse_limit(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 and n <= @max_limit -> n
      _ -> @default_limit
    end
  end
end
