defmodule ApiWeb.GrowthMeasurementController do
  use ApiWeb, :controller

  alias Api.Babies
  alias Api.Babies.Baby
  alias Api.GrowthMeasurements
  alias Api.GrowthMeasurements.GrowthMeasurement
  alias Api.Reports

  action_fallback ApiWeb.FallbackController

  # No date-range params here, unlike ExportController's `show/2` — the
  # Growth page has no range picker of its own (occasional entries, not a
  # quick-log stream), so this always exports the baby's full history.
  def export(conn, %{"baby_id" => baby_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, baby_id) do
      locale = parse_locale(params)
      pdf = Reports.growth_pdf(baby, locale)
      filename = "babycheck-#{slug(baby.name)}-growth.pdf"

      conn
      |> put_resp_content_type("application/pdf")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> send_resp(200, pdf)
    else
      nil -> {:error, :not_found}
    end
  end

  defp parse_locale(%{"locale" => "pt-BR"}), do: "pt-BR"
  defp parse_locale(_params), do: "en"

  defp slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  def index(conn, %{"baby_id" => baby_id}) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, baby_id) do
      render(conn, :index, growth_measurements: GrowthMeasurements.list_measurements(baby))
    else
      nil -> {:error, :not_found}
    end
  end

  def create(conn, %{"baby_id" => baby_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, baby_id),
         {:ok, measurement} <- GrowthMeasurements.create_measurement(baby, params) do
      conn
      |> put_status(:created)
      |> render(:show, growth_measurement: measurement)
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %GrowthMeasurement{} = measurement <-
           GrowthMeasurements.get_measurement_for_user(user, id),
         {:ok, measurement} <- GrowthMeasurements.update_measurement(measurement, params) do
      render(conn, :show, growth_measurement: measurement)
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with %GrowthMeasurement{} = measurement <-
           GrowthMeasurements.get_measurement_for_user(user, id),
         {:ok, _measurement} <- GrowthMeasurements.delete_measurement(measurement) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
    end
  end
end
