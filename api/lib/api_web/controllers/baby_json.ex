defmodule ApiWeb.BabyJSON do
  alias Api.Babies.Baby

  def index(%{babies: babies}) do
    %{data: Enum.map(babies, &data/1)}
  end

  def show(%{baby: baby}) do
    %{data: data(baby)}
  end

  defp data(%Baby{} = baby) do
    %{id: baby.id, name: baby.name, theme_color: baby.theme_color}
  end
end
