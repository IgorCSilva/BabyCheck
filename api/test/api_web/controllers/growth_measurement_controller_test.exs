defmodule ApiWeb.GrowthMeasurementControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.GrowthMeasurements

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

  defp authed_conn(conn, user) do
    {:ok, access_token, _refresh} = Accounts.create_session(user, false)
    put_req_header(conn, "authorization", "Bearer #{access_token}")
  end

  describe "GET /api/babies/:baby_id/growth_measurements/export" do
    test "requires authentication", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn = get(conn, ~p"/api/babies/#{baby.id}/growth_measurements/export")
      assert json_response(conn, 401)
    end

    test "returns a PDF attachment named after the baby", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      measurement_fixture(baby)

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/growth_measurements/export")

      assert conn.status == 200
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "application/pdf"
      assert [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ "attachment"
      assert disposition =~ "riley"
      assert disposition =~ "growth"
      assert String.starts_with?(conn.resp_body, "%PDF-")
    end

    test "renders pt-BR text when the locale param asks for it", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      measurement_fixture(baby)

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/growth_measurements/export", %{"locale" => "pt-BR"})

      assert conn.status == 200

      text =
        ~r/stream\r?\n(.*?)endstream/s
        |> Regex.scan(conn.resp_body)
        |> Enum.map(fn [_, stream] -> :zlib.uncompress(stream) end)
        |> Enum.join("\n")
        |> :unicode.characters_to_binary(:latin1, :utf8)

      assert text =~ "Medidas de Crescimento"
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{other_baby.id}/growth_measurements/export")

      assert json_response(conn, 404)
    end
  end

  describe "GET /api/babies/:baby_id/growth_measurements" do
    test "requires authentication", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn = get(conn, ~p"/api/babies/#{baby.id}/growth_measurements")
      assert json_response(conn, 401)
    end

    test "lists only the given baby's measurements, newest first", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      other_baby = baby_fixture(user, %{name: "Sam", theme_color: "#9DC8E8"})
      measurement = measurement_fixture(baby)
      measurement_fixture(other_baby)

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/growth_measurements")

      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == measurement.id
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{other_baby.id}/growth_measurements")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/babies/:baby_id/growth_measurements" do
    test "creates a measurement with explicit fields", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies/#{baby.id}/growth_measurements", %{
          "weight_kg" => 4.2,
          "height_cm" => 55.0,
          "measured_at" => "2026-11-20"
        })

      assert %{"data" => %{"id" => id, "weight_kg" => 4.2, "height_cm" => 55.0}} =
               json_response(conn, 201)

      assert is_integer(id)
    end

    test "accepts weight or height alone", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies/#{baby.id}/growth_measurements", %{
          "weight_kg" => 4.2,
          "measured_at" => "2026-11-20"
        })

      assert %{"data" => %{"weight_kg" => 4.2, "height_cm" => nil}} = json_response(conn, 201)
    end

    test "rejects a measurement with neither weight nor height", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies/#{baby.id}/growth_measurements", %{"measured_at" => "2026-11-20"})

      assert json_response(conn, 422)
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/api/babies/#{other_baby.id}/growth_measurements", %{
          "weight_kg" => 4.2,
          "measured_at" => "2026-11-20"
        })

      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/growth_measurements/:id" do
    test "updates a measurement owned by the current user", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      measurement = measurement_fixture(baby)

      conn =
        conn
        |> authed_conn(user)
        |> put(~p"/api/growth_measurements/#{measurement.id}", %{
          "weight_kg" => 5.1,
          "height_cm" => 58.0,
          "measured_at" => "2026-11-21"
        })

      assert %{"data" => %{"weight_kg" => 5.1, "height_cm" => 58.0}} = json_response(conn, 200)
    end

    test "returns 404 for another user's measurement", %{conn: conn} do
      user = user_fixture()
      other_measurement = measurement_fixture(baby_fixture(user_fixture()))

      conn =
        conn
        |> authed_conn(user)
        |> put(~p"/api/growth_measurements/#{other_measurement.id}", %{"weight_kg" => 5.1})

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/growth_measurements/:id" do
    test "removes a measurement owned by the current user", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      measurement = measurement_fixture(baby)

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/growth_measurements/#{measurement.id}")

      assert response(conn, 204)
      assert GrowthMeasurements.list_measurements(baby) == []
    end

    test "returns 404 for another user's measurement", %{conn: conn} do
      user = user_fixture()
      other_measurement = measurement_fixture(baby_fixture(user_fixture()))

      conn =
        conn
        |> authed_conn(user)
        |> delete(~p"/api/growth_measurements/#{other_measurement.id}")

      assert json_response(conn, 404)
    end
  end
end
