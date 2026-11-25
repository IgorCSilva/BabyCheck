defmodule Api.BottleFeedings do
  @moduledoc """
  Bottle-feedings for a single baby. Mirrors `Api.DiaperLogs`: index/create
  are scoped by a `Baby` struct the caller already fetched, so the baby/user
  ownership check happens exactly once, in one place. Update/delete take a
  bare feeding id and re-derive ownership by joining through `babies`.
  """

  import Ecto.Query, warn: false

  alias Api.Repo
  alias Api.Accounts.User
  alias Api.Babies.Baby
  alias Api.BottleFeedings.BottleFeeding

  def list_feedings(%Baby{} = baby, opts \\ []) do
    BottleFeeding
    |> where(baby_id: ^baby.id)
    |> filter_from(Keyword.get(opts, :from))
    |> filter_to(Keyword.get(opts, :to))
    |> order_by(desc: :logged_at)
    |> Repo.all()
  end

  defp filter_from(query, nil), do: query
  defp filter_from(query, from), do: where(query, [feeding], feeding.logged_at >= ^from)

  defp filter_to(query, nil), do: query
  defp filter_to(query, to), do: where(query, [feeding], feeding.logged_at <= ^to)

  def get_feeding(%Baby{} = baby, id) do
    with {id, ""} <- Integer.parse(to_string(id)) do
      BottleFeeding
      |> where(baby_id: ^baby.id, id: ^id)
      |> Repo.one()
    else
      _ -> nil
    end
  end

  def get_feeding_for_user(%User{} = user, id) do
    with {id, ""} <- Integer.parse(to_string(id)) do
      BottleFeeding
      |> join(:inner, [feeding], baby in Baby, on: baby.id == feeding.baby_id)
      |> where([feeding, baby], baby.user_id == ^user.id and feeding.id == ^id)
      |> select([feeding, baby], feeding)
      |> Repo.one()
    else
      _ -> nil
    end
  end

  def create_feeding(%Baby{} = baby, attrs) do
    %BottleFeeding{baby_id: baby.id}
    |> BottleFeeding.changeset(attrs)
    |> Repo.insert()
  end

  def update_feeding(%BottleFeeding{} = feeding, attrs) do
    feeding
    |> BottleFeeding.changeset(attrs)
    |> Repo.update()
  end

  def delete_feeding(%BottleFeeding{} = feeding) do
    Repo.delete(feeding)
  end
end
