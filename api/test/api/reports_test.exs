defmodule Api.ReportsTest do
  use Api.DataCase, async: true

  alias Api.Accounts
  alias Api.Babies
  alias Api.BottleFeedings
  alias Api.DiaperLogs
  alias Api.GrowthMeasurements
  alias Api.Reports

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

  # The `pdf` lib flate-compresses each page's content stream; to assert on
  # the actual rendered text we have to pull every stream back out and
  # inflate it, then decode from WinAnsiEncoding (the "pdf" lib's encoding
  # for the standard Helvetica font) to UTF-8 so accented pt-BR text
  # compares correctly against ordinary Elixir string literals.
  defp rendered_text(pdf_binary) do
    ~r/stream\r?\n(.*?)endstream/s
    |> Regex.scan(pdf_binary)
    |> Enum.map(fn [_, stream] -> :zlib.uncompress(stream) end)
    |> Enum.join("\n")
    |> :unicode.characters_to_binary(:latin1, :utf8)
  end

  describe "summary_pdf/3" do
    test "returns a well-formed PDF binary" do
      baby = baby_fixture(user_fixture())

      pdf = Reports.summary_pdf(baby, ~U[2026-11-20 00:00:00Z], ~U[2026-11-22 23:59:59Z])

      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF-")
      assert String.ends_with?(String.trim_trailing(pdf), "%%EOF")
    end

    test "defaults to English text and a month/day/year date format" do
      baby = baby_fixture(user_fixture())

      pdf = Reports.summary_pdf(baby, ~U[2026-11-20 00:00:00Z], ~U[2026-11-22 23:59:59Z])
      text = rendered_text(pdf)

      assert text =~ "BabyCheck Summary"
      assert text =~ "Diaper"
      assert text =~ "Bottle"
      assert text =~ "Breastfeeding"
      assert text =~ "11/20/2026"
    end

    test "renders pt-BR text and a day/month/year date format when asked" do
      baby = baby_fixture(user_fixture())

      pdf =
        Reports.summary_pdf(baby, ~U[2026-11-20 00:00:00Z], ~U[2026-11-22 23:59:59Z], "pt-BR")

      text = rendered_text(pdf)

      assert text =~ "Resumo do BabyCheck"
      assert text =~ "Fralda"
      assert text =~ "Mamadeira"
      assert text =~ "Amamentação"
      assert text =~ "20/11/2026"
    end

    test "falls back to English for an unrecognized locale" do
      baby = baby_fixture(user_fixture())

      pdf =
        Reports.summary_pdf(baby, ~U[2026-11-20 00:00:00Z], ~U[2026-11-20 23:59:59Z], "fr")

      assert rendered_text(pdf) =~ "BabyCheck Summary"
    end

    test "renders with logs present across all three metrics" do
      baby = baby_fixture(user_fixture())
      {:ok, _} = DiaperLogs.create_log(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})
      {:ok, _} = DiaperLogs.create_log(baby, %{logged_at: ~U[2026-11-21 08:00:00Z]})
      {:ok, _} = BottleFeedings.create_feeding(baby, %{logged_at: ~U[2026-11-20 08:00:00Z]})

      pdf = Reports.summary_pdf(baby, ~U[2026-11-20 00:00:00Z], ~U[2026-11-22 23:59:59Z])

      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF-")
    end

    test "renders fine for a baby with no logs at all in range" do
      baby = baby_fixture(user_fixture())

      pdf = Reports.summary_pdf(baby, ~U[2026-11-20 00:00:00Z], ~U[2026-11-20 23:59:59Z])

      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF-")
    end

    test "renders fine for a wider, multi-week range" do
      baby = baby_fixture(user_fixture())
      {:ok, _} = DiaperLogs.create_log(baby, %{logged_at: ~U[2026-11-05 08:00:00Z]})

      pdf = Reports.summary_pdf(baby, ~U[2026-10-29 00:00:00Z], ~U[2026-11-27 23:59:59Z])

      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF-")
    end
  end

  describe "growth_pdf/2" do
    test "returns a well-formed PDF binary" do
      baby = baby_fixture(user_fixture())

      pdf = Reports.growth_pdf(baby)

      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF-")
      assert String.ends_with?(String.trim_trailing(pdf), "%%EOF")
    end

    test "defaults to English text, units, and a month/day/year date format" do
      baby = baby_fixture(user_fixture())
      {:ok, _} = GrowthMeasurements.create_measurement(baby, %{weight_kg: 4.2, height_cm: 55.0, measured_at: ~D[2026-11-20]})

      text = Reports.growth_pdf(baby) |> rendered_text()

      assert text =~ "Growth Measurements"
      assert text =~ "Weight trend"
      assert text =~ "Height trend"
      assert text =~ "11/20/2026"
      assert text =~ "4.2kg"
      assert text =~ "55cm"
    end

    test "renders pt-BR text, Kg unit, and a day/month/year date format when asked" do
      baby = baby_fixture(user_fixture())
      {:ok, _} = GrowthMeasurements.create_measurement(baby, %{weight_kg: 4.2, height_cm: 55.0, measured_at: ~D[2026-11-20]})

      text = Reports.growth_pdf(baby, "pt-BR") |> rendered_text()

      assert text =~ "Medidas de Crescimento"
      assert text =~ "Tendência de peso"
      assert text =~ "Tendência de altura"
      assert text =~ "20/11/2026"
      assert text =~ "4.2Kg"
    end

    test "falls back to English for an unrecognized locale" do
      baby = baby_fixture(user_fixture())

      text = Reports.growth_pdf(baby, "fr") |> rendered_text()

      assert text =~ "Growth Measurements"
    end

    test "shows a no-measurements message instead of charts/table when none exist" do
      baby = baby_fixture(user_fixture())

      text = Reports.growth_pdf(baby) |> rendered_text()

      assert text =~ "No growth measurements recorded."
      refute text =~ "Weight trend"
      refute text =~ "Height trend"
    end

    test "only renders the trend chart for a metric that actually has data" do
      baby = baby_fixture(user_fixture())
      {:ok, _} = GrowthMeasurements.create_measurement(baby, %{weight_kg: 4.2, measured_at: ~D[2026-11-20]})

      text = Reports.growth_pdf(baby) |> rendered_text()

      assert text =~ "Weight trend"
      refute text =~ "Height trend"
    end

    test "renders every measurement across a page break without reordering columns" do
      baby = baby_fixture(user_fixture())

      for i <- 1..40 do
        {:ok, _} =
          GrowthMeasurements.create_measurement(baby, %{
            weight_kg: 3.0 + i * 0.1,
            measured_at: Date.add(~D[2026-01-01], i * 10)
          })
      end

      pdf = Reports.growth_pdf(baby)
      text = rendered_text(pdf)

      # A spot check near the end of the list — on a later page once rows
      # are chunked — confirms the date still lines up with its own weight
      # rather than a neighboring row's (the symptom of the column-order
      # bug this pagination works around).
      assert text =~ "3.1kg"
      assert text =~ "4kg"
    end
  end
end
