defmodule Api.GrowthMeasurementsTest do
  use Api.DataCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.GrowthMeasurements
  alias Api.GrowthMeasurements.GrowthMeasurement

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

  defp measurement_fixture(baby, attrs \\ %{}) do
    {:ok, measurement} =
      attrs
      |> Enum.into(%{weight_kg: 4.2, height_cm: 55.0, measured_at: ~D[2026-11-20]})
      |> then(&GrowthMeasurements.create_measurement(baby, &1))

    measurement
  end

  describe "create_measurement/2" do
    test "creates a measurement scoped to the baby" do
      baby = baby_fixture(user_fixture())

      assert {:ok, %GrowthMeasurement{} = measurement} =
               GrowthMeasurements.create_measurement(baby, %{
                 weight_kg: 4.2,
                 height_cm: 55.0,
                 measured_at: ~D[2026-11-20]
               })

      assert measurement.baby_id == baby.id
      assert measurement.weight_kg == 4.2
      assert measurement.height_cm == 55.0
      assert measurement.measured_at == ~D[2026-11-20]
    end

    test "accepts weight only" do
      baby = baby_fixture(user_fixture())

      assert {:ok, measurement} =
               GrowthMeasurements.create_measurement(baby, %{
                 weight_kg: 4.2,
                 measured_at: ~D[2026-11-20]
               })

      assert measurement.weight_kg == 4.2
      assert measurement.height_cm == nil
    end

    test "accepts height only" do
      baby = baby_fixture(user_fixture())

      assert {:ok, measurement} =
               GrowthMeasurements.create_measurement(baby, %{
                 height_cm: 55.0,
                 measured_at: ~D[2026-11-20]
               })

      assert measurement.weight_kg == nil
      assert measurement.height_cm == 55.0
    end

    test "requires measured_at" do
      baby = baby_fixture(user_fixture())

      assert {:error, changeset} =
               GrowthMeasurements.create_measurement(baby, %{weight_kg: 4.2})

      assert "can't be blank" in errors_on(changeset).measured_at
    end

    test "requires at least one of weight or height" do
      baby = baby_fixture(user_fixture())

      assert {:error, changeset} =
               GrowthMeasurements.create_measurement(baby, %{measured_at: ~D[2026-11-20]})

      assert errors_on(changeset).weight_kg != nil
    end

    test "rejects a non-positive weight or height" do
      baby = baby_fixture(user_fixture())

      assert {:error, changeset} =
               GrowthMeasurements.create_measurement(baby, %{
                 weight_kg: -1,
                 measured_at: ~D[2026-11-20]
               })

      assert "must be greater than 0" in errors_on(changeset).weight_kg
    end
  end

  describe "list_measurements/1" do
    test "only returns the given baby's measurements, newest first" do
      baby = baby_fixture(user_fixture())
      other_baby = baby_fixture(user_fixture())

      older = measurement_fixture(baby, %{measured_at: ~D[2026-11-01]})
      newer = measurement_fixture(baby, %{measured_at: ~D[2026-11-20]})
      measurement_fixture(other_baby)

      assert [%GrowthMeasurement{id: first_id}, %GrowthMeasurement{id: second_id}] =
               GrowthMeasurements.list_measurements(baby)

      assert first_id == newer.id
      assert second_id == older.id
    end
  end

  describe "get_measurement_for_user/2" do
    test "returns the measurement when it belongs to the user's baby" do
      user = user_fixture()
      baby = baby_fixture(user)
      measurement = measurement_fixture(baby)

      assert %GrowthMeasurement{id: id} =
               GrowthMeasurements.get_measurement_for_user(user, measurement.id)

      assert id == measurement.id
    end

    test "returns nil for another user's measurement" do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())
      measurement = measurement_fixture(other_baby)

      assert GrowthMeasurements.get_measurement_for_user(user, measurement.id) == nil
    end

    test "returns nil for a non-numeric id instead of raising" do
      user = user_fixture()
      assert GrowthMeasurements.get_measurement_for_user(user, "not-an-id") == nil
    end
  end

  describe "update_measurement/2" do
    test "updates the weight, height, and date" do
      measurement = measurement_fixture(baby_fixture(user_fixture()))

      assert {:ok, updated} =
               GrowthMeasurements.update_measurement(measurement, %{
                 weight_kg: 5.1,
                 height_cm: 58.0,
                 measured_at: ~D[2026-11-21]
               })

      assert updated.weight_kg == 5.1
      assert updated.height_cm == 58.0
      assert updated.measured_at == ~D[2026-11-21]
    end
  end

  describe "delete_measurement/1" do
    test "removes the measurement" do
      baby = baby_fixture(user_fixture())
      measurement = measurement_fixture(baby)

      assert {:ok, _} = GrowthMeasurements.delete_measurement(measurement)
      assert GrowthMeasurements.list_measurements(baby) == []
    end
  end
end
