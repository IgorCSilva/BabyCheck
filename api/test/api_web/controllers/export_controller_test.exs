defmodule ApiWeb.ExportControllerTest do
  use ApiWeb.ConnCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.DiaperLogs

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

  defp authed_conn(conn, user) do
    {:ok, access_token, _refresh} = Accounts.create_session(user, false)
    put_req_header(conn, "authorization", "Bearer #{access_token}")
  end

  describe "GET /api/babies/:baby_id/export" do
    test "requires authentication", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn = get(conn, ~p"/api/babies/#{baby.id}/export")
      assert json_response(conn, 401)
    end

    test "returns a PDF attachment with the baby's summary", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)
      {:ok, _} = DiaperLogs.create_log(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/export", %{
          "from" => "2026-11-20T00:00:00Z",
          "to" => "2026-11-22T23:59:59Z"
        })

      assert conn.status == 200
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "application/pdf"
      assert [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ "attachment"
      assert disposition =~ "riley"
      assert String.starts_with?(conn.resp_body, "%PDF-")
    end

    test "falls back to the default range when from/to are missing", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/export")

      assert conn.status == 200
      assert String.starts_with?(conn.resp_body, "%PDF-")
    end

    test "renders pt-BR text when the locale param asks for it", %{conn: conn} do
      user = user_fixture()
      baby = baby_fixture(user)

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{baby.id}/export", %{"locale" => "pt-BR"})

      assert conn.status == 200

      text =
        ~r/stream\r?\n(.*?)endstream/s
        |> Regex.scan(conn.resp_body)
        |> Enum.map(fn [_, stream] -> :zlib.uncompress(stream) end)
        |> Enum.join("\n")
        |> :unicode.characters_to_binary(:latin1, :utf8)

      assert text =~ "Resumo do BabyCheck"
    end

    test "returns 404 for another user's baby", %{conn: conn} do
      user = user_fixture()
      other_baby = baby_fixture(user_fixture())

      conn =
        conn
        |> authed_conn(user)
        |> get(~p"/api/babies/#{other_baby.id}/export")

      assert json_response(conn, 404)
    end
  end
end
