defmodule Api.GrowthMeasurements do
  @moduledoc """
  Weight/height measurements for a single baby — occasional, dated entries
  taken at e.g. a pediatrician visit, not quick-logs. Each is editable and
  deletable. Index/create are scoped by a `Baby` struct the caller already
  fetched, so the baby/user ownership check happens exactly once, in one
  place. Update/delete take a bare measurement id and re-derive ownership by
  joining through `babies`, mirroring `Api.DiaperLogs` and friends.
  """

  import Ecto.Query, warn: false

  alias Api.Repo
  alias Api.Accounts.User
  alias Api.Babies.Baby
  alias Api.GrowthMeasurements.GrowthMeasurement

  def list_measurements(%Baby{} = baby) do
    GrowthMeasurement
    |> where(baby_id: ^baby.id)
    |> order_by(desc: :measured_at)
    |> Repo.all()
  end

  def get_measurement_for_user(%User{} = user, id) do
    with {id, ""} <- Integer.parse(to_string(id)) do
      GrowthMeasurement
      |> join(:inner, [m], baby in Baby, on: baby.id == m.baby_id)
      |> where([m, baby], baby.user_id == ^user.id and m.id == ^id)
      |> select([m, baby], m)
      |> Repo.one()
    else
      _ -> nil
    end
  end

  def create_measurement(%Baby{} = baby, attrs) do
    %GrowthMeasurement{baby_id: baby.id}
    |> GrowthMeasurement.changeset(attrs)
    |> Repo.insert()
  end

  def update_measurement(%GrowthMeasurement{} = measurement, attrs) do
    measurement
    |> GrowthMeasurement.changeset(attrs)
    |> Repo.update()
  end

  def delete_measurement(%GrowthMeasurement{} = measurement) do
    Repo.delete(measurement)
  end
end
