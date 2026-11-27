defmodule Api.Repo.Migrations.CreateGrowthMeasurements do
  use Ecto.Migration

  def change do
    create table(:growth_measurements) do
      add :baby_id, references(:babies, on_delete: :delete_all), null: false
      add :weight_kg, :float
      add :height_cm, :float
      add :measured_at, :date, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:growth_measurements, [:baby_id])
    create index(:growth_measurements, [:baby_id, :measured_at])
  end
end
