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
      formula_g: entry.formula_g,
      weight_kg: entry.weight_kg,
      height_cm: entry.height_cm
    }
  end

  defp summary_data(baby_summary) do
    %{
      baby_id: baby_summary.baby_id,
      baby_name: baby_summary.baby_name,
      baby_theme_color: baby_summary.baby_theme_color,
      diaper_last_logged_at: baby_summary.diaper_last_logged_at,
      bottle_last_logged_at: baby_summary.bottle_last_logged_at,
      breastfeeding_last_logged_at: baby_summary.breastfeeding_last_logged_at,
      diaper_avg_per_day_7d: baby_summary.diaper_avg_per_day_7d,
      bottle_avg_per_day_7d: baby_summary.bottle_avg_per_day_7d,
      breastfeeding_avg_per_day_7d: baby_summary.breastfeeding_avg_per_day_7d,
      diaper_long_gap: baby_summary.diaper_long_gap,
      bottle_long_gap: baby_summary.bottle_long_gap,
      breastfeeding_long_gap: baby_summary.breastfeeding_long_gap
    }
  end
end
