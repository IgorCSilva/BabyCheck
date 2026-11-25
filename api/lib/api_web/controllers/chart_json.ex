defmodule ApiWeb.ChartJSON do
  def index(%{charts: charts}) do
    %{
      data: %{
        diaper: Enum.map(charts.diaper, &point/1),
        bottle: Enum.map(charts.bottle, &point/1),
        breastfeeding: Enum.map(charts.breastfeeding, &point/1)
      }
    }
  end

  defp point(%{date: date, count: count}) do
    %{date: Date.to_iso8601(date), count: count}
  end
end
