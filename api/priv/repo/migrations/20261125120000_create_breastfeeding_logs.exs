defmodule Api.Repo.Migrations.CreateBreastfeedingLogs do
  use Ecto.Migration

  def change do
    create table(:breastfeeding_logs) do
      add :baby_id, references(:babies, on_delete: :delete_all), null: false
      add :logged_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:breastfeeding_logs, [:baby_id])
    create index(:breastfeeding_logs, [:baby_id, :logged_at])
  end
end
