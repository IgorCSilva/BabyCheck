defmodule ApiWeb.BottleFeedingJSON do
  alias Api.BottleFeedings.BottleFeeding

  def index(%{bottle_feedings: bottle_feedings}) do
    %{data: Enum.map(bottle_feedings, &data/1)}
  end

  def show(%{bottle_feeding: bottle_feeding}) do
    %{data: data(bottle_feeding)}
  end

  defp data(%BottleFeeding{} = bottle_feeding) do
    %{
      id: bottle_feeding.id,
      baby_id: bottle_feeding.baby_id,
      logged_at: bottle_feeding.logged_at,
      water_ml: bottle_feeding.water_ml,
      formula_g: bottle_feeding.formula_g
    }
  end
end
