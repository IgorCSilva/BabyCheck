defmodule ApiWeb.FallbackController do
  use ApiWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: translate_errors(changeset)})
  end

  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: %{detail: "invalid email or password", code: "invalid_credentials"}})
  end

  def call(conn, {:error, :invalid_or_expired_token}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "invalid or expired token", code: "invalid_token"}})
  end

  def call(conn, {:error, :invalid_or_expired}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: %{detail: "invalid or expired session", code: "invalid_session"}})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{errors: %{detail: "not found", code: "not_found"}})
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
