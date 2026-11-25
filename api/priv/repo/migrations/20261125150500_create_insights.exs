defmodule Api.Repo.Migrations.CreateInsights do
  use Ecto.Migration

  def change do
    create table(:insights) do
      add :baby_id, references(:babies, on_delete: :delete_all), null: false
      add :metric, :string, null: false
      add :avg_per_day_7d, :float, null: false, default: 0.0
      add :long_gap, :boolean, null: false, default: false
      add :computed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:insights, [:baby_id, :metric])
  end
end
