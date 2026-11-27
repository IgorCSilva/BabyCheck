defmodule ApiWeb.GrowthMeasurementJSON do
  alias Api.GrowthMeasurements.GrowthMeasurement

  def index(%{growth_measurements: growth_measurements}) do
    %{data: Enum.map(growth_measurements, &data/1)}
  end

  def show(%{growth_measurement: growth_measurement}) do
    %{data: data(growth_measurement)}
  end

  defp data(%GrowthMeasurement{} = growth_measurement) do
    %{
      id: growth_measurement.id,
      baby_id: growth_measurement.baby_id,
      weight_kg: growth_measurement.weight_kg,
      height_cm: growth_measurement.height_cm,
      measured_at: growth_measurement.measured_at
    }
  end
end
