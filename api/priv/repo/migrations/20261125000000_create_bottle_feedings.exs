defmodule Api.Repo.Migrations.CreateBottleFeedings do
  use Ecto.Migration

  def change do
    create table(:bottle_feedings) do
      add :baby_id, references(:babies, on_delete: :delete_all), null: false
      add :logged_at, :utc_datetime, null: false
      add :water_ml, :integer, null: false, default: 30
      add :formula_g, :integer, null: false, default: 10

      timestamps(type: :utc_datetime)
    end

    create index(:bottle_feedings, [:baby_id])
    create index(:bottle_feedings, [:baby_id, :logged_at])
  end
end
