defmodule Api.DiaperLogs.DiaperLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "diaper_logs" do
    field :logged_at, :utc_datetime
    field :peed, :boolean, default: true
    field :pooped, :boolean, default: true
    field :client_request_id, :string
    belongs_to :baby, Api.Babies.Baby

    timestamps(type: :utc_datetime)
  end

  def changeset(diaper_log, attrs) do
    diaper_log
    |> cast(attrs, [:logged_at, :peed, :pooped, :client_request_id])
    |> validate_required([:logged_at])
    |> unique_constraint(:client_request_id)
  end
end
