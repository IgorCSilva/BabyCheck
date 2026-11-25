defmodule ApiWeb.BottleFeedingController do
  use ApiWeb, :controller

  alias Api.Babies
  alias Api.Babies.Baby
  alias Api.BottleFeedings
  alias Api.BottleFeedings.BottleFeeding

  action_fallback ApiWeb.FallbackController

  def index(conn, %{"baby_id" => baby_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, baby_id) do
      opts = [from: parse_datetime(params["from"]), to: parse_datetime(params["to"])]
      render(conn, :index, bottle_feedings: BottleFeedings.list_feedings(baby, opts))
    else
      nil -> {:error, :not_found}
    end
  end

  def create(conn, %{"baby_id" => baby_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, baby_id),
         attrs <- Map.put_new(params, "logged_at", DateTime.to_iso8601(DateTime.utc_now())),
         {:ok, feeding} <- BottleFeedings.create_feeding(baby, attrs) do
      conn
      |> put_status(:created)
      |> render(:show, bottle_feeding: feeding)
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %BottleFeeding{} = feeding <- BottleFeedings.get_feeding_for_user(user, id),
         {:ok, feeding} <- BottleFeedings.update_feeding(feeding, params) do
      render(conn, :show, bottle_feeding: feeding)
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with %BottleFeeding{} = feeding <- BottleFeedings.get_feeding_for_user(user, id),
         {:ok, _feeding} <- BottleFeedings.delete_feeding(feeding) do
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
