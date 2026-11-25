defmodule Api.Repo.Migrations.CreateDiaperLogs do
  use Ecto.Migration

  def change do
    create table(:diaper_logs) do
      add :baby_id, references(:babies, on_delete: :delete_all), null: false
      add :logged_at, :utc_datetime, null: false
      add :peed, :boolean, null: false, default: true
      add :pooped, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:diaper_logs, [:baby_id])
    create index(:diaper_logs, [:baby_id, :logged_at])
  end
end
