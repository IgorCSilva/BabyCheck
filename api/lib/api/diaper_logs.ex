defmodule Api.DiaperLogs do
  @moduledoc """
  Diaper changes for a single baby. Index/create are scoped by a `Baby`
  struct the caller already fetched (see `Api.Babies.get_baby/2`), so the
  baby/user ownership check happens exactly once, in one place. Update/delete
  take a bare log id and re-derive ownership by joining through `babies`,
  since a log id alone says nothing about which account can touch it.
  """

  import Ecto.Query, warn: false

  alias Api.Repo
  alias Api.Accounts.User
  alias Api.Babies.Baby
  alias Api.DiaperLogs.DiaperLog

  def list_logs(%Baby{} = baby, opts \\ []) do
    DiaperLog
    |> where(baby_id: ^baby.id)
    |> filter_from(Keyword.get(opts, :from))
    |> filter_to(Keyword.get(opts, :to))
    |> order_by(desc: :logged_at)
    |> Repo.all()
  end

  defp filter_from(query, nil), do: query
  defp filter_from(query, from), do: where(query, [log], log.logged_at >= ^from)

  defp filter_to(query, nil), do: query
  defp filter_to(query, to), do: where(query, [log], log.logged_at <= ^to)

  def get_log(%Baby{} = baby, id) do
    with {id, ""} <- Integer.parse(to_string(id)) do
      DiaperLog
      |> where(baby_id: ^baby.id, id: ^id)
      |> Repo.one()
    else
      _ -> nil
    end
  end

  def get_log_for_user(%User{} = user, id) do
    with {id, ""} <- Integer.parse(to_string(id)) do
      DiaperLog
      |> join(:inner, [log], baby in Baby, on: baby.id == log.baby_id)
      |> where([log, baby], baby.user_id == ^user.id and log.id == ^id)
      |> select([log, baby], log)
      |> Repo.one()
    else
      _ -> nil
    end
  end

  def create_log(%Baby{} = baby, attrs) do
    %DiaperLog{baby_id: baby.id}
    |> DiaperLog.changeset(attrs)
    |> Repo.insert()
  end

  def update_log(%DiaperLog{} = log, attrs) do
    log
    |> DiaperLog.changeset(attrs)
    |> Repo.update()
  end

  def delete_log(%DiaperLog{} = log) do
    Repo.delete(log)
  end
end
