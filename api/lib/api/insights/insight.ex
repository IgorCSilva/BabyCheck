defmodule Api.Insights.Insight do
  use Ecto.Schema
  import Ecto.Changeset

  schema "insights" do
    field :metric, :string
    field :avg_per_day_7d, :float
    field :long_gap, :boolean, default: false
    field :computed_at, :utc_datetime
    belongs_to :baby, Api.Babies.Baby

    timestamps(type: :utc_datetime)
  end

  def changeset(insight, attrs) do
    insight
    |> cast(attrs, [:baby_id, :metric, :avg_per_day_7d, :long_gap, :computed_at])
    |> validate_required([:baby_id, :metric, :avg_per_day_7d, :long_gap, :computed_at])
    |> validate_inclusion(:metric, ~w(diaper bottle breastfeeding))
  end
end
