defmodule ApiWeb.DiaperLogJSON do
  alias Api.DiaperLogs.DiaperLog

  def index(%{diaper_logs: diaper_logs}) do
    %{data: Enum.map(diaper_logs, &data/1)}
  end

  def show(%{diaper_log: diaper_log}) do
    %{data: data(diaper_log)}
  end

  defp data(%DiaperLog{} = diaper_log) do
    %{
      id: diaper_log.id,
      baby_id: diaper_log.baby_id,
      logged_at: diaper_log.logged_at,
      peed: diaper_log.peed,
      pooped: diaper_log.pooped
    }
  end
end
