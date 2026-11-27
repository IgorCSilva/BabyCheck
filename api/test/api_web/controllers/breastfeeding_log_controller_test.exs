defmodule ApiWeb.BreastfeedingLogControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.BreastfeedingLogs

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
      |> then(&BreastfeedingLogs.create_log(baby, &1))

    log
  end

  defp authed_conn(conn, user) do
    {:ok, access_token, _refresh} = Accounts.create_session(user, false)
    put_req_header(conn, "authorization", "Bearer #{access_token}")
  end

  describe "GET /api/babies/:baby_id/breastfeeding_logs" do
    test "requires authentication", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn = get(conn, ~p"/api/babies/#{baby.id}/breastfeeding_logs")
      assert json_response(conn, 401)
    end

    test "lists only the given baby's logs", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      other_baby = baby_fixture(user, %{name: "Sam", theme_color: "#9DC8E8"})
      log = log_fixture(baby)
      log_fixture(other_baby)

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/breastfeeding_logs")

      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == log.id
    end

    test "filters by from/to", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      log_fixture(baby, %{logged_at: ~U[2026-11-19 08:00:00Z]})
      in_range = log_fixture(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/breastfeeding_logs", %{
          "from" => "2026-11-20T00:00:00Z",
          "to" => "2026-11-20T23:59:59Z"
        })

      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == in_range.id
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{other_baby.id}/breastfeeding_logs")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/babies/:baby_id/breastfeeding_logs" do
    test "creates a log with an explicit timestamp", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies/#{baby.id}/breastfeeding_logs", %{
          "logged_at" => "2026-11-20T08:00:00Z"
        })

      assert %{"data" => %{"id" => id, "logged_at" => "2026-11-20T08:00:00Z"}} =
               json_response(conn, 201)

      assert is_integer(id)
    end

    test "defaults logged_at for a one-tap log", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies/#{baby.id}/breastfeeding_logs", %{})

      assert %{"data" => %{"logged_at" => logged_at}} = json_response(conn, 201)
      assert is_binary(logged_at)
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies/#{other_baby.id}/breastfeeding_logs", %{})

      assert json_response(conn, 404)
    end

    test "a repeated client_request_id (e.g. an offline retry) doesn't create a duplicate", %{
      conn: conn
    } do
      user = user_fixture()
      baby = baby_fixture(user)
      body = %{"logged_at" => "2026-11-20T08:00:00Z", "client_request_id" => "temp-456"}

      conn = conn |> authed_conn(user)
      first = post(conn, ~p"/api/babies/#{baby.id}/breastfeeding_logs", body)
      second = post(conn, ~p"/api/babies/#{baby.id}/breastfeeding_logs", body)

      assert %{"data" => %{"id" => first_id}} = json_response(first, 201)
      assert %{"data" => %{"id" => second_id}} = json_response(second, 201)
      assert first_id == second_id
      assert length(BreastfeedingLogs.list_logs(baby)) == 1
    end
  end

  describe "PUT /api/breastfeeding_logs/:id" do
    test "updates a log owned by the current user", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      log = log_fixture(baby)

      conn =
        conn
        |> authed_conn(user)
        |> put(~p"/api/breastfeeding_logs/#{log.id}", %{"logged_at" => "2026-11-21T09:30:00Z"})

      assert %{"data" => %{"logged_at" => "2026-11-21T09:30:00Z"}} = json_response(conn, 200)
    end

    test "returns 404 for another user's log", %{conn: conn} do
      user = user_fixture()
      other_log = log_fixture(baby_fixture(user_fixture()))

      conn =
        conn
        |> authed_conn(user)
        |> put(~p"/api/breastfeeding_logs/#{other_log.id}", %{
          "logged_at" => "2026-11-21T09:30:00Z"
        })

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/breastfeeding_logs/:id" do
    test "removes a log owned by the current user", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      log = log_fixture(baby)

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/breastfeeding_logs/#{log.id}")

      assert response(conn, 204)
      assert BreastfeedingLogs.list_logs(baby) == []
    end

    test "returns 404 for another user's log", %{conn: conn} do
      user = user_fixture()
      other_log = log_fixture(baby_fixture(user_fixture()))

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/breastfeeding_logs/#{other_log.id}")

      assert json_response(conn, 404)
    end
  end
end
