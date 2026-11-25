defmodule Api.BottleFeedingsTest do
  use Api.DataCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.BottleFeedings
  alias Api.BottleFeedings.BottleFeeding

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

  defp feeding_fixture(baby, attrs \\ %{}) do
    {:ok, feeding} =
      attrs
      |> Enum.into(%{logged_at: ~U[2026-11-20 08:00:00Z]})
      |> then(&BottleFeedings.create_feeding(baby, &1))

    feeding
  end

  describe "create_feeding/2" do
    test "creates a feeding scoped to the baby, defaulting water and formula" do
      baby = baby_fixture(user_fixture())

      assert {:ok, %BottleFeeding{} = feeding} =
               BottleFeedings.create_feeding(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})

      assert feeding.baby_id == baby.id
      assert feeding.logged_at == ~U[2026-11-20 08:00:00Z]
      assert feeding.water_ml == 30
      assert feeding.formula_g == 10
    end

    test "accepts explicit water/formula amounts" do
      baby = baby_fixture(user_fixture())

      assert {:ok, feeding} =
               BottleFeedings.create_feeding(baby, %{
                 logged_at: ~U[2026-11-20 08:00:00Z],
                 water_ml: 60,
                 formula_g: 20
               })

      assert feeding.water_ml == 60
      assert feeding.formula_g == 20
    end

    test "requires logged_at" do
      baby = baby_fixture(user_fixture())

      assert {:error, changeset} = BottleFeedings.create_feeding(baby, %{})
      assert "can't be blank" in errors_on(changeset).logged_at
    end

    test "rejects negative amounts" do
      baby = baby_fixture(user_fixture())

      assert {:error, changeset} =
               BottleFeedings.create_feeding(baby, %{
                 logged_at: ~U[2026-11-20 08:00:00Z],
                 water_ml: -5
               })

      assert "must be greater than or equal to 0" in errors_on(changeset).water_ml
    end
  end

  describe "list_feedings/2" do
    test "only returns the given baby's feedings, newest first" do
      baby = baby_fixture(user_fixture())
      other_baby = baby_fixture(user_fixture())

      older = feeding_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})
      newer = feeding_fixture(baby, %{logged_at: ~U[2026-11-21 08:00:00Z]})
      feeding_fixture(other_baby)

      assert [%BottleFeeding{id: first_id}, %BottleFeeding{id: second_id}] =
               BottleFeedings.list_feedings(baby)

      assert first_id == newer.id
      assert second_id == older.id
    end

    test "filters by an inclusive from/to range" do
      baby = baby_fixture(user_fixture())

      feeding_fixture(baby, %{logged_at: ~U[2026-11-19 08:00:00Z]})
      in_range = feeding_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})
      feeding_fixture(baby, %{logged_at: ~U[2026-11-22 08:00:00Z]})

      feedings =
        BottleFeedings.list_feedings(baby,
          from: ~U[2026-11-20 00:00:00Z],
          to: ~U[2026-11-20 23:59:59Z]
        )

      assert [%BottleFeeding{id: id}] = feedings
      assert id == in_range.id
    end
  end

  describe "get_feeding_for_user/2" do
    test "returns the feeding when it belongs to the user's baby" do
      user = user_fixture()
      baby = baby_fixture(user)
      feeding = feeding_fixture(baby)

      assert %BottleFeeding{id: id} = BottleFeedings.get_feeding_for_user(user, feeding.id)
      assert id == feeding.id
    end

    test "returns nil for another user's feeding" do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())
      feeding = feeding_fixture(other_baby)

      assert BottleFeedings.get_feeding_for_user(user, feeding.id) == nil
    end

    test "returns nil for a non-numeric id instead of raising" do
      user = user_fixture()
      assert BottleFeedings.get_feeding_for_user(user, "not-an-id") == nil
    end
  end

  describe "update_feeding/2" do
    test "updates the timestamp and amounts" do
      feeding = feeding_fixture(baby_fixture(user_fixture()))

      assert {:ok, updated} =
               BottleFeedings.update_feeding(feeding, %{
                 logged_at: ~U[2026-11-21 09:30:00Z],
                 water_ml: 45,
                 formula_g: 15
               })

      assert updated.logged_at == ~U[2026-11-21 09:30:00Z]
      assert updated.water_ml == 45
      assert updated.formula_g == 15
    end
  end

  describe "delete_feeding/1" do
    test "removes the feeding" do
      baby = baby_fixture(user_fixture())
      feeding = feeding_fixture(baby)

      assert {:ok, _} = BottleFeedings.delete_feeding(feeding)
      assert BottleFeedings.list_feedings(baby) == []
    end
  end
end
