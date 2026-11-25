defmodule Api.DiaperLogsTest do
  use Api.DataCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.DiaperLogs
  alias Api.DiaperLogs.DiaperLog

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

  defp log_fixture(baby, attrs \\ %{}) do
    {:ok, log} =
      attrs
      |> Enum.into(%{logged_at: ~U[2026-11-20 08:00:00Z]})
      |> then(&DiaperLogs.create_log(baby, &1))

    log
  end

  describe "create_log/2" do
    test "creates a log scoped to the baby, defaulting peed and pooped to true" do
      baby = baby_fixture(user_fixture())

      assert {:ok, %DiaperLog{} = log} =
               DiaperLogs.create_log(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})

      assert log.baby_id == baby.id
      assert log.logged_at == ~U[2026-11-20 08:00:00Z]
      assert log.peed == true
      assert log.pooped == true
    end

    test "accepts explicit peed/pooped flags" do
      baby = baby_fixture(user_fixture())

      assert {:ok, log} =
               DiaperLogs.create_log(baby, %{
                 logged_at: ~U[2026-11-20 08:00:00Z],
                 peed: false,
                 pooped: true
               })

      assert log.peed == false
      assert log.pooped == true
    end

    test "requires logged_at" do
      baby = baby_fixture(user_fixture())

      assert {:error, changeset} = DiaperLogs.create_log(baby, %{})
      assert "can't be blank" in errors_on(changeset).logged_at
    end
  end

  describe "list_logs/2" do
    test "only returns the given baby's logs, newest first" do
      baby = baby_fixture(user_fixture())
      other_baby = baby_fixture(user_fixture())

      older = log_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})
      newer = log_fixture(baby, %{logged_at: ~U[2026-11-21 08:00:00Z]})
      log_fixture(other_baby)

      assert [%DiaperLog{id: first_id}, %DiaperLog{id: second_id}] = DiaperLogs.list_logs(baby)
      assert first_id == newer.id
      assert second_id == older.id
    end

    test "filters by an inclusive from/to range" do
      baby = baby_fixture(user_fixture())

      log_fixture(baby, %{logged_at: ~U[2026-11-19 08:00:00Z]})
      in_range = log_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})
      log_fixture(baby, %{logged_at: ~U[2026-11-22 08:00:00Z]})

      logs =
        DiaperLogs.list_logs(baby,
          from: ~U[2026-11-20 00:00:00Z],
          to: ~U[2026-11-20 23:59:59Z]
        )

      assert [%DiaperLog{id: id}] = logs
      assert id == in_range.id
    end
  end

  describe "get_log_for_user/2" do
    test "returns the log when it belongs to the user's baby" do
      user = user_fixture()
      baby = baby_fixture(user)
      log = log_fixture(baby)

      assert %DiaperLog{id: id} = DiaperLogs.get_log_for_user(user, log.id)
      assert id == log.id
    end

    test "returns nil for another user's log" do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())
      log = log_fixture(other_baby)

      assert DiaperLogs.get_log_for_user(user, log.id) == nil
    end

    test "returns nil for a non-numeric id instead of raising" do
      user = user_fixture()
      assert DiaperLogs.get_log_for_user(user, "not-an-id") == nil
    end
  end

  describe "update_log/2" do
    test "updates the timestamp and flags" do
      log = log_fixture(baby_fixture(user_fixture()))

      assert {:ok, updated} =
               DiaperLogs.update_log(log, %{
                 logged_at: ~U[2026-11-21 09:30:00Z],
                 peed: false,
                 pooped: false
               })

      assert updated.logged_at == ~U[2026-11-21 09:30:00Z]
      assert updated.peed == false
      assert updated.pooped == false
    end
  end

  describe "delete_log/1" do
    test "removes the log" do
      baby = baby_fixture(user_fixture())
      log = log_fixture(baby)

      assert {:ok, _} = DiaperLogs.delete_log(log)
      assert DiaperLogs.list_logs(baby) == []
    end
  end
end
