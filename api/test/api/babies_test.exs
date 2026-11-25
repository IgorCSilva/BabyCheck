defmodule Api.BabiesTest do
  use Api.DataCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.Babies.Baby

  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "parent#{System.unique_integer()}@example.com",
        password: "supersecret123",
        password_confirmation: "supersecret123"
      })
      |> Accounts.register_user()

    user
  end

  defp baby_fixture(user, attrs \\ %{}) do
    {:ok, baby} =
      attrs
      |> Enum.into(%{name: "Riley", theme_color: "#F5A9B8"})
      |> then(&Babies.create_baby(user, &1))

    baby
  end

  describe "create_baby/2" do
    test "creates a baby scoped to the user" do
      user = user_fixture()

      assert {:ok, %Baby{} = baby} =
               Babies.create_baby(user, %{name: "Riley", theme_color: "#F5A9B8"})

      assert baby.user_id == user.id
      assert baby.name == "Riley"
      assert baby.theme_color == "#F5A9B8"
    end

    test "requires a name" do
      user = user_fixture()

      assert {:error, changeset} = Babies.create_baby(user, %{theme_color: "#F5A9B8"})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires a valid hex theme color" do
      user = user_fixture()

      assert {:error, changeset} = Babies.create_baby(user, %{name: "Riley", theme_color: "pink"})
      assert "must be a hex color like #F5A9B8" in errors_on(changeset).theme_color
    end
  end

  describe "list_babies/1" do
    test "only returns the given user's babies" do
      user = user_fixture()
      other_user = user_fixture()

      baby = baby_fixture(user)
      baby_fixture(other_user)

      assert [%Baby{id: id}] = Babies.list_babies(user)
      assert id == baby.id
    end
  end

  describe "get_baby/2" do
    test "returns the baby when it belongs to the user" do
      user = user_fixture()
      baby = baby_fixture(user)

      assert %Baby{id: id} = Babies.get_baby(user, baby.id)
      assert id == baby.id
    end

    test "returns nil for another user's baby" do
      user = user_fixture()
      other_user = user_fixture()
      baby = baby_fixture(other_user)

      assert Babies.get_baby(user, baby.id) == nil
    end

    test "returns nil for a non-numeric id instead of raising" do
      user = user_fixture()
      assert Babies.get_baby(user, "not-an-id") == nil
    end
  end

  describe "update_baby/2" do
    test "updates the name and theme color" do
      user = user_fixture()
      baby = baby_fixture(user)

      assert {:ok, updated} = Babies.update_baby(baby, %{name: "Sam", theme_color: "#9DC8E8"})
      assert updated.name == "Sam"
      assert updated.theme_color == "#9DC8E8"
    end
  end

  describe "delete_baby/1" do
    test "removes the baby" do
      user = user_fixture()
      baby = baby_fixture(user)

      assert {:ok, _} = Babies.delete_baby(baby)
      assert Babies.list_babies(user) == []
    end
  end
end
