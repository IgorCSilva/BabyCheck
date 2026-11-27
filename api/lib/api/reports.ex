defmodule Api.Reports do
  @moduledoc """
  Renders the same per-day aggregates `Api.Charts` feeds to the Step 7
  charts as a single, printable PDF page per baby — a totals table plus
  the three metric charts stacked below, meant to be handed to a
  pediatrician rather than read on screen. No app chrome and no theme
  color (per the roadmap's design note for this step): bars are plain
  grayscale, distinguished by shade rather than the baby's accent color.

  The PDF text and date format follow whichever UI locale the Vue app had
  active when the export was requested (sent as a `locale` param, since
  rendering happens server-side with no session-level locale of its own)
  — this app has no other backend-rendered, user-facing text to localize,
  so a small literal table here is enough; it doesn't need Gettext.
  """

  alias Api.Babies.Baby
  alias Api.Charts

  @default_locale "en"

  @strings %{
    "en" => %{
      metric: "Metric",
      total: "Total",
      diaper: "Diaper",
      bottle: "Bottle",
      breastfeeding: "Breastfeeding",
      title: "BabyCheck Summary",
      range_separator: "to"
    },
    "pt-BR" => %{
      metric: "Métrica",
      total: "Total",
      diaper: "Fralda",
      bottle: "Mamadeira",
      breastfeeding: "Amamentação",
      title: "Resumo do BabyCheck",
      range_separator: "até"
    }
  }

  @metric_colors [
    diaper: {90, 90, 90},
    bottle: {130, 130, 130},
    breastfeeding: {170, 170, 170}
  ]

  @page_width 595
  @page_height 842
  @margin 40
  @content_width @page_width - 2 * @margin

  @table_header_background {230, 230, 230}

  @table_height 130
  @chart_height 130
  @chart_gap 36

  # Reserves room to the left of the bars for the y-axis value labels, so
  # the gridlines and the first bar never overlap the numbers.
  @axis_gutter 20
  @gridline_color {205, 205, 205}
  @axis_label_color {110, 110, 110}
  @dash_length 3
  @dash_gap 2

  def summary_pdf(%Baby{} = baby, %DateTime{} = from, %DateTime{} = to, locale \\ @default_locale) do
    charts = Charts.daily_counts(baby, from, to)
    strings = Map.get(@strings, locale, @strings[@default_locale])

    Pdf.build([size: :a4, compress: true], fn pdf ->
      pdf
      |> Pdf.set_info(title: "#{strings.title} - #{baby.name}")
      |> draw_header(baby, from, to, strings, locale)
      |> draw_totals_table(charts, strings)
      |> draw_charts(charts, strings, locale)
      |> Pdf.export()
    end)
  end

  defp draw_header(pdf, baby, from, to, strings, locale) do
    pdf
    |> Pdf.set_font("Helvetica", size: 18, bold: true)
    |> Pdf.text_at({@margin, @page_height - @margin - 8}, strings.title)
    |> Pdf.set_font("Helvetica", size: 11)
    |> Pdf.text_at(
      {@margin, @page_height - @margin - 28},
      "#{baby.name}  -  #{format_date(from, locale)} #{strings.range_separator} #{format_date(to, locale)}"
    )
  end

  defp draw_totals_table(pdf, charts, strings) do
    data_rows =
      Enum.map(@metric_colors, fn {key, _color} ->
        [Map.fetch!(strings, key), Integer.to_string(total(charts[key]))]
      end)

    table =
      Pdf.Table.new([], border: 1, padding: 6)
      |> Pdf.Table.add_row([strings.metric, strings.total], background: @table_header_background)
      |> Pdf.Table.add_rows(data_rows)

    Pdf.render_table!(
      pdf,
      {@margin, @page_height - @margin - 45},
      {@content_width, @table_height},
      table
    )
  end

  defp total(series), do: Enum.reduce(series, 0, fn %{count: count}, acc -> acc + count end)

  defp draw_charts(pdf, charts, strings, locale) do
    top = @page_height - @margin - 45 - @table_height - 20

    {pdf, _top} =
      Enum.reduce(@metric_colors, {pdf, top}, fn {key, color}, {pdf, chart_top} ->
        label = Map.fetch!(strings, key)
        pdf = draw_chart(pdf, label, color, charts[key], chart_top, locale)
        {pdf, chart_top - @chart_height - @chart_gap}
      end)

    pdf
  end

  defp draw_chart(pdf, label, color, series, chart_top, locale) do
    raw_max = series |> Enum.map(& &1.count) |> Enum.max(fn -> 0 end) |> max(1)
    step = nice_step(raw_max)
    axis_max = step * ceil_div(raw_max, step)

    bar_area_top = chart_top - 18
    bar_area_bottom = chart_top - @chart_height + 14
    bar_area_height = bar_area_top - bar_area_bottom

    bars_x_start = @margin + @axis_gutter
    bars_width = @content_width - @axis_gutter

    n = length(series)
    bar_slot = bars_width / max(n, 1)
    bar_width = max(bar_slot * 0.6, 1)
    label_every = max(div(n, 8), 1)

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", size: 12, bold: true)
      |> Pdf.set_fill_color(:black)
      |> Pdf.text_at({@margin, chart_top}, label)

    pdf = draw_gridlines(pdf, bars_x_start, bar_area_bottom, bar_area_height, step, axis_max)

    pdf = Pdf.set_font(pdf, "Helvetica", size: 7)

    series
    |> Enum.with_index()
    |> Enum.reduce(pdf, fn {%{date: date, count: count}, index}, pdf ->
      x = bars_x_start + index * bar_slot + (bar_slot - bar_width) / 2

      pdf =
        if count > 0 do
          bar_height = max(bar_area_height * count / axis_max, 2)

          pdf
          |> Pdf.set_fill_color(color)
          |> Pdf.rectangle({x, bar_area_bottom}, {bar_width, bar_height})
          |> Pdf.fill()
        else
          pdf
        end

      if rem(index, label_every) == 0 do
        pdf
        |> Pdf.set_fill_color(@axis_label_color)
        |> Pdf.text_at({x, bar_area_bottom - 10}, day_label(date, locale))
      else
        pdf
      end
    end)
  end

  # A handful of round, human-friendly gridline values (1, 2, 5, 10, 20, …)
  # rather than one per raw unit — matters because `max_count` is often a
  # small, irregular number (e.g. 7), and a dashed line plus label at every
  # single count would clutter more than it clarifies.
  defp nice_step(max_value) do
    cond do
      max_value <= 5 -> 1
      max_value <= 10 -> 2
      max_value <= 25 -> 5
      max_value <= 50 -> 10
      max_value <= 100 -> 20
      max_value <= 250 -> 50
      true -> 100
    end
  end

  defp ceil_div(a, b), do: div(a + b - 1, b)

  defp draw_gridlines(pdf, bars_x_start, bar_area_bottom, bar_area_height, step, axis_max) do
    line_end_x = @margin + @content_width

    pdf =
      pdf
      |> Pdf.set_stroke_color(@gridline_color)
      |> Pdf.set_line_width(0.75)

    pdf =
      step
      |> Stream.iterate(&(&1 + step))
      |> Enum.take_while(&(&1 <= axis_max))
      |> Enum.reduce(pdf, fn value, pdf ->
        y = bar_area_bottom + bar_area_height * value / axis_max
        draw_dashed_hline(pdf, bars_x_start, line_end_x, y)
      end)

    pdf
    |> Pdf.set_font("Helvetica", size: 6)
    |> Pdf.set_fill_color(@axis_label_color)
    |> draw_axis_labels(bars_x_start, bar_area_bottom, bar_area_height, step, axis_max)
  end

  defp draw_axis_labels(pdf, bars_x_start, bar_area_bottom, bar_area_height, step, axis_max) do
    step
    |> Stream.iterate(&(&1 + step))
    |> Enum.take_while(&(&1 <= axis_max))
    |> Enum.reduce(pdf, fn value, pdf ->
      y = bar_area_bottom + bar_area_height * value / axis_max
      Pdf.text_at(pdf, {bars_x_start - @axis_gutter + 2, y - 2}, Integer.to_string(value))
    end)
  end

  defp draw_dashed_hline(pdf, x1, x2, y) do
    segment = @dash_length + @dash_gap

    0
    |> Stream.iterate(&(&1 + segment))
    |> Enum.take_while(&(x1 + &1 < x2))
    |> Enum.reduce(pdf, fn offset, pdf ->
      dash_start = x1 + offset
      dash_end = min(dash_start + @dash_length, x2)

      pdf
      |> Pdf.line({dash_start, y}, {dash_end, y})
      |> Pdf.stroke()
    end)
  end

  # pt-BR reads dates day-first (27/11), matching how the rest of the app
  # already formats dates for that locale (toLocaleDateString in the Vue
  # app); en keeps the month-first format this module always used.
  defp day_label(%Date{} = date, "pt-BR"), do: "#{date.day}/#{date.month}"
  defp day_label(%Date{} = date, _locale), do: "#{date.month}/#{date.day}"

  defp format_date(%DateTime{} = datetime, locale) do
    date = DateTime.to_date(datetime)

    case locale do
      "pt-BR" -> "#{date.day}/#{date.month}/#{date.year}"
      _ -> "#{date.month}/#{date.day}/#{date.year}"
    end
  end
end
