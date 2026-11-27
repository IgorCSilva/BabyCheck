defmodule ApiWeb.ExportController do
  use ApiWeb, :controller

  alias Api.Babies
  alias Api.Babies.Baby
  alias Api.Reports

  action_fallback ApiWeb.FallbackController

  @default_days 6

  def show(conn, %{"baby_id" => baby_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, baby_id) do
      {from, to} = parse_range(params)
      locale = parse_locale(params)
      pdf = Reports.summary_pdf(baby, from, to, locale)
      filename = "babycheck-#{slug(baby.name)}-summary.pdf"

      conn
      |> put_resp_content_type("application/pdf")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> send_resp(200, pdf)
    else
      nil -> {:error, :not_found}
    end
  end

  # Only the two locales the Vue app actually supports are recognized;
  # anything else (missing param, unknown value) falls back to English,
  # same tolerance as the range parsing below.
  defp parse_locale(%{"locale" => "pt-BR"}), do: "pt-BR"
  defp parse_locale(_params), do: "en"

  defp slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  # Same tolerant fallback as ChartController: a missing/malformed range
  # just falls back to the last 7 days rather than a validation error.
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
