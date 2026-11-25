defmodule Api.Repo.Migrations.CreateBabies do
  use Ecto.Migration

  def change do
    create table(:babies) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :theme_color, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:babies, [:user_id])
  end
end
