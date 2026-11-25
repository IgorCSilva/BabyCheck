defmodule ApiWeb.BreastfeedingLogController do
  use ApiWeb, :controller

  alias Api.Babies
  alias Api.Babies.Baby
  alias Api.BreastfeedingLogs
  alias Api.BreastfeedingLogs.BreastfeedingLog

  action_fallback ApiWeb.FallbackController

  def index(conn, %{"baby_id" => baby_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, baby_id) do
      opts = [from: parse_datetime(params["from"]), to: parse_datetime(params["to"])]
      render(conn, :index, breastfeeding_logs: BreastfeedingLogs.list_logs(baby, opts))
    else
      nil -> {:error, :not_found}
    end
  end

  def create(conn, %{"baby_id" => baby_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, baby_id),
         attrs <- Map.put_new(params, "logged_at", DateTime.to_iso8601(DateTime.utc_now())),
         {:ok, log} <- BreastfeedingLogs.create_log(baby, attrs) do
      conn
      |> put_status(:created)
      |> render(:show, breastfeeding_log: log)
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %BreastfeedingLog{} = log <- BreastfeedingLogs.get_log_for_user(user, id),
         {:ok, log} <- BreastfeedingLogs.update_log(log, params) do
      render(conn, :show, breastfeeding_log: log)
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with %BreastfeedingLog{} = log <- BreastfeedingLogs.get_log_for_user(user, id),
         {:ok, _log} <- BreastfeedingLogs.delete_log(log) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
    end
  end

  # The range filters are computed client-side from the device's local
  # time, so a malformed value here just means "don't filter" rather than
  # a user-facing validation error.
  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end
end
