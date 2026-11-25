defmodule Api.Guardian do
  use Guardian, otp_app: :api

  alias Api.Accounts
  alias Api.Accounts.User

  def subject_for_token(%User{id: id}, _claims), do: {:ok, to_string(id)}
  def subject_for_token(_, _), do: {:error, :invalid_resource}

  def resource_from_claims(%{"sub" => id}) do
    {:ok, Accounts.get_user!(id)}
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def resource_from_claims(_claims), do: {:error, :invalid_claims}
end
