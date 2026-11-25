defmodule Api.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :hashed_password, :string, redact: true
    field :password, :string, virtual: true, redact: true
    field :password_confirmation, :string, virtual: true, redact: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  Casts and validates email + password for a brand new account.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :password_confirmation])
    |> validate_email()
    |> validate_password()
  end

  @doc """
  Casts and validates a new password, e.g. for the password-reset flow.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_password()
  end

  defp validate_email(changeset) do
    changeset
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Api.Repo)
    |> unique_constraint(:email)
  end

  defp normalize_email(email) when is_binary(email), do: String.downcase(String.trim(email))
  defp normalize_email(email), do: email

  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_length(:password, min: 8, max: 72)
    |> maybe_hash_password()
  end

  defp maybe_hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
      |> delete_change(:password_confirmation)
    else
      changeset
    end
  end
end
