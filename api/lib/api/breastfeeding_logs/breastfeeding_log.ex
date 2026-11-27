defmodule Api.BreastfeedingLogs.BreastfeedingLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "breastfeeding_logs" do
    field :logged_at, :utc_datetime
    field :client_request_id, :string
    belongs_to :baby, Api.Babies.Baby

    timestamps(type: :utc_datetime)
  end

  def changeset(breastfeeding_log, attrs) do
    breastfeeding_log
    |> cast(attrs, [:logged_at, :client_request_id])
    |> validate_required([:logged_at])
    |> unique_constraint(:client_request_id)
  end
end
