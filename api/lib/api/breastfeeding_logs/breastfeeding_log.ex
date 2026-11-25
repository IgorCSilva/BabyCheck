defmodule Api.BreastfeedingLogs.BreastfeedingLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "breastfeeding_logs" do
    field :logged_at, :utc_datetime
    belongs_to :baby, Api.Babies.Baby

    timestamps(type: :utc_datetime)
  end

  def changeset(breastfeeding_log, attrs) do
    breastfeeding_log
    |> cast(attrs, [:logged_at])
    |> validate_required([:logged_at])
  end
end
