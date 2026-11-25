defmodule Api.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 12)
  end

  # Oban.Migration.down/1 destroys the oban_jobs table entirely, even if
  # you've requested to only roll back one version.
  def down do
    Oban.Migration.down(version: 1)
  end
end
