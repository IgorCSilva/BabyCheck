defmodule ApiWeb.BabyController do
  use ApiWeb, :controller

  alias Api.Babies
  alias Api.Babies.Baby

  action_fallback ApiWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    render(conn, :index, babies: Babies.list_babies(user))
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, baby} <- Babies.create_baby(user, params) do
      conn
      |> put_status(:created)
      |> render(:show, baby: baby)
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, id),
         {:ok, baby} <- Babies.update_baby(baby, params) do
      render(conn, :show, baby: baby)
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with %Baby{} = baby <- Babies.get_baby(user, id),
         {:ok, _baby} <- Babies.delete_baby(baby) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
    end
  end
end
