defmodule ApiWeb.FeedJSON do
  def index(%{entries: entries}) do
    %{data: Enum.map(entries, &entry_data/1)}
  end

  def summary(%{summary: summary}) do
    %{data: Enum.map(summary, &summary_data/1)}
  end

  defp entry_data(entry) do
    %{
      type: entry.type,
      id: entry.id,
      baby_id: entry.baby_id,
      baby_name: entry.baby_name,
      baby_theme_color: entry.baby_theme_color,
      logged_at: entry.logged_at,
      peed: entry.peed,
      pooped: entry.pooped,
      water_ml: entry.water_ml,
      formula_g: entry.formula_g
    }
  end

  defp summary_data(baby_summary) do
    %{
      baby_id: baby_summary.baby_id,
      baby_name: baby_summary.baby_name,
      baby_theme_color: baby_summary.baby_theme_color,
      diaper_last_logged_at: baby_summary.diaper_last_logged_at,
      bottle_last_logged_at: baby_summary.bottle_last_logged_at,
      breastfeeding_last_logged_at: baby_summary.breastfeeding_last_logged_at
    }
  end
end
