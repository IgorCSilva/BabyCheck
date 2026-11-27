defmodule Api.Repo.Migrations.AddClientRequestIdToLogs do
  use Ecto.Migration

  def change do
    for table_name <- [:diaper_logs, :bottle_feedings, :breastfeeding_logs] do
      alter table(table_name) do
        add :client_request_id, :string
      end

      create unique_index(table_name, [:client_request_id])
    end
  end
end
