defmodule ApiWeb.AuthJSON do
  def session(%{user: user, access_token: access_token}) do
    %{data: %{user: user_data(user), access_token: access_token}}
  end

  defp user_data(user) do
    %{id: user.id, email: user.email}
  end
end
