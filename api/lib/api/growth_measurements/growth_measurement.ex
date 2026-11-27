defmodule Api.GrowthMeasurements.GrowthMeasurement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "growth_measurements" do
    field :weight_kg, :float
    field :height_cm, :float
    field :measured_at, :date
    belongs_to :baby, Api.Babies.Baby

    timestamps(type: :utc_datetime)
  end

  def changeset(growth_measurement, attrs) do
    growth_measurement
    |> cast(attrs, [:weight_kg, :height_cm, :measured_at])
    |> validate_required([:measured_at])
    |> validate_number(:weight_kg, greater_than: 0)
    |> validate_number(:height_cm, greater_than: 0)
    |> validate_at_least_one_measurement()
  end

  # Either field can be left blank for a visit where only one was taken, but
  # not both — an entry with neither isn't a measurement at all.
  defp validate_at_least_one_measurement(changeset) do
    if is_nil(get_field(changeset, :weight_kg)) and is_nil(get_field(changeset, :height_cm)) do
      add_error(changeset, :weight_kg, "weight or height must be present")
    else
      changeset
    end
  end
end
