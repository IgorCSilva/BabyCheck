defmodule Api.Babies do
  @moduledoc """
  Babies belong to one account and every log in later steps is scoped to
  one. All lookups here are scoped by `user_id` so one account can never
  read, edit, or delete another account's baby.
  """

  import Ecto.Query, warn: false

  alias Api.Repo
  alias Api.Accounts.User
  alias Api.Babies.Baby

  def list_babies(%User{} = user) do
    Baby
    |> where(user_id: ^user.id)
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  # Takes the id as whatever the router handed us (a string, usually) and
  # only ever looks it up scoped to this user — an unparsable or
  # out-of-scope id both simply mean "not found" to the caller.
  def get_baby(%User{} = user, id) do
    with {id, ""} <- Integer.parse(to_string(id)) do
      Baby
      |> where(user_id: ^user.id, id: ^id)
      |> Repo.one()
    else
      _ -> nil
    end
  end

  def create_baby(%User{} = user, attrs) do
    %Baby{user_id: user.id}
    |> Baby.changeset(attrs)
    |> Repo.insert()
  end

  def update_baby(%Baby{} = baby, attrs) do
    baby
    |> Baby.changeset(attrs)
    |> Repo.update()
  end

  def delete_baby(%Baby{} = baby) do
    Repo.delete(baby)
  end
end
