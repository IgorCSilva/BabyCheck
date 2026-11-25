defmodule ApiWeb.BreastfeedingLogJSON do
  alias Api.BreastfeedingLogs.BreastfeedingLog

  def index(%{breastfeeding_logs: breastfeeding_logs}) do
    %{data: Enum.map(breastfeeding_logs, &data/1)}
  end

  def show(%{breastfeeding_log: breastfeeding_log}) do
    %{data: data(breastfeeding_log)}
  end

  defp data(%BreastfeedingLog{} = breastfeeding_log) do
    %{
      id: breastfeeding_log.id,
      baby_id: breastfeeding_log.baby_id,
      logged_at: breastfeeding_log.logged_at
    }
  end
end
