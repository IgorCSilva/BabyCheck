defmodule Api.Babies.Baby do
  use Ecto.Schema
  import Ecto.Changeset

  schema "babies" do
    field :name, :string
    field :theme_color, :string
    belongs_to :user, Api.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(baby, attrs) do
    baby
    |> cast(attrs, [:name, :theme_color])
    |> validate_required([:name, :theme_color])
    |> validate_length(:name, min: 1, max: 60)
    |> validate_format(:theme_color, ~r/^#[0-9A-Fa-f]{6}$/,
      message: "must be a hex color like #F5A9B8"
    )
  end
end
