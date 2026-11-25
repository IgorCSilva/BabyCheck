defmodule Api.Insights.ComputeInsightsWorker do
  @moduledoc """
  Runs on a cron schedule (see `config :api, Oban` in config.exs) to keep the
  stored `insights` table warm for every baby, independent of anyone having
  the app open — see `Api.Insights` for why that's a separate concern from
  the feed's own always-fresh insight chips.
  """

  use Oban.Worker, queue: :insights, max_attempts: 3

  alias Api.Insights

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Insights.recompute_and_store_all!()
    :ok
  end
end
