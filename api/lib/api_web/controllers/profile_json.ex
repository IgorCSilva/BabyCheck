defmodule ApiWeb.ProfileJSON do
  def show(%{user: user}) do
    %{data: %{id: user.id, email: user.email}}
  end
end
