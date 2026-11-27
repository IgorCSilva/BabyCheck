defmodule Api.BottleFeedings.BottleFeeding do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bottle_feedings" do
    field :logged_at, :utc_datetime
    field :water_ml, :integer, default: 30
    field :formula_g, :integer, default: 10
    field :client_request_id, :string
    belongs_to :baby, Api.Babies.Baby

    timestamps(type: :utc_datetime)
  end

  def changeset(bottle_feeding, attrs) do
    bottle_feeding
    |> cast(attrs, [:logged_at, :water_ml, :formula_g, :client_request_id])
    |> validate_required([:logged_at])
    |> validate_number(:water_ml, greater_than_or_equal_to: 0)
    |> validate_number(:formula_g, greater_than_or_equal_to: 0)
    |> unique_constraint(:client_request_id)
  end
end
