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
  alias Api.GrowthMeasurements

  @default_locale "en"

  @strings %{
    "en" => %{
      metric: "Metric",
      total: "Total",
      diaper: "Diaper",
      bottle: "Bottle",
      breastfeeding: "Breastfeeding",
      title: "BabyCheck Summary",
      range_separator: "to",
      growth_title: "Growth Measurements",
      date: "Date",
      weight: "Weight",
      height: "Height",
      weight_unit: "kg",
      height_unit: "cm",
      weight_trend: "Weight trend",
      height_trend: "Height trend",
      no_measurements: "No growth measurements recorded."
    },
    "pt-BR" => %{
      metric: "Métrica",
      total: "Total",
      diaper: "Fralda",
      bottle: "Mamadeira",
      breastfeeding: "Amamentação",
      title: "Resumo do BabyCheck",
      range_separator: "até",
      growth_title: "Medidas de Crescimento",
      date: "Data",
      weight: "Peso",
      height: "Altura",
      weight_unit: "Kg",
      height_unit: "cm",
      weight_trend: "Tendência de peso",
      height_trend: "Tendência de altura",
      no_measurements: "Nenhuma medida de crescimento registrada."
    }
  }

  @metric_colors [
    diaper: {90, 90, 90},
    bottle: {130, 130, 130},
    breastfeeding: {170, 170, 170}
  ]

  @growth_colors [weight: {100, 100, 100}, height: {150, 150, 150}]
  @growth_point_size 4
  @growth_line_width 1.25
  @float_epsilon 0.0001
  @growth_table_row_height 26

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

  # A standalone, single-metric counterpart to `summary_pdf/4` — the Growth
  # page has no date-range picker of its own (it always shows a baby's full
  # history, occasional entries rather than a quick-log stream), so this
  # always exports everything on record rather than a selected range.
  def growth_pdf(%Baby{} = baby, locale \\ @default_locale) do
    measurements = GrowthMeasurements.list_measurements(baby)
    strings = Map.get(@strings, locale, @strings[@default_locale])

    Pdf.build([size: :a4, compress: true], fn pdf ->
      pdf
      |> Pdf.set_info(title: "#{strings.growth_title} - #{baby.name}")
      |> draw_growth_header(baby, strings)
      |> draw_growth_body(measurements, strings, locale)
      |> Pdf.export()
    end)
  end

  defp draw_growth_header(pdf, baby, strings) do
    pdf
    |> Pdf.set_font("Helvetica", size: 18, bold: true)
    |> Pdf.set_fill_color(:black)
    |> Pdf.text_at({@margin, @page_height - @margin - 8}, strings.growth_title)
    |> Pdf.set_font("Helvetica", size: 11)
    |> Pdf.text_at({@margin, @page_height - @margin - 28}, baby.name)
  end

  defp draw_growth_body(pdf, measurements, strings, locale) do
    top = @page_height - @margin - 45

    weight_points =
      measurements
      |> Enum.filter(&(&1.weight_kg != nil))
      |> Enum.sort_by(& &1.measured_at, Date)

    height_points =
      measurements
      |> Enum.filter(&(&1.height_cm != nil))
      |> Enum.sort_by(& &1.measured_at, Date)

    {pdf, top} =
      draw_growth_chart_if_present(pdf, weight_points, :weight_kg, @growth_colors[:weight], top, strings, locale)

    {pdf, top} =
      draw_growth_chart_if_present(pdf, height_points, :height_cm, @growth_colors[:height], top, strings, locale)

    draw_growth_table(pdf, measurements, strings, locale, top)
  end

  defp draw_growth_chart_if_present(pdf, [], _field, _color, top, _strings, _locale), do: {pdf, top}

  defp draw_growth_chart_if_present(pdf, points, field, color, top, strings, locale) do
    {label, unit} =
      case field do
        :weight_kg -> {strings.weight_trend, strings.weight_unit}
        :height_cm -> {strings.height_trend, strings.height_unit}
      end

    pdf = draw_trend_chart(pdf, "#{label} (#{unit})", color, points, field, top, locale)
    {pdf, top - @chart_height - @chart_gap}
  end

  defp draw_trend_chart(pdf, label, color, points, field, chart_top, locale) do
    values = Enum.map(points, &Map.fetch!(&1, field))
    {axis_min, axis_max, step} = nice_float_range(Enum.min(values), Enum.max(values))

    bar_area_top = chart_top - 18
    bar_area_bottom = chart_top - @chart_height + 14
    bar_area_height = bar_area_top - bar_area_bottom

    plot_x_start = @margin + @axis_gutter
    plot_width = @content_width - @axis_gutter

    n = length(points)
    slot = if n > 1, do: plot_width / (n - 1), else: 0
    label_every = max(div(n, 8), 1)

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", size: 12, bold: true)
      |> Pdf.set_fill_color(:black)
      |> Pdf.text_at({@margin, chart_top}, label)

    pdf =
      draw_value_gridlines(pdf, plot_x_start, bar_area_bottom, bar_area_height, axis_min, axis_max, step)

    coords =
      points
      |> Enum.with_index()
      |> Enum.map(fn {entry, index} ->
        value = Map.fetch!(entry, field)
        x = if n == 1, do: plot_x_start + plot_width / 2, else: plot_x_start + index * slot
        y = bar_area_bottom + bar_area_height * (value - axis_min) / (axis_max - axis_min)
        {entry, index, x, y}
      end)

    pdf =
      coords
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(pdf, fn [{_, _, x1, y1}, {_, _, x2, y2}], pdf ->
        pdf
        |> Pdf.set_stroke_color(color)
        |> Pdf.set_line_width(@growth_line_width)
        |> Pdf.line({x1, y1}, {x2, y2})
        |> Pdf.stroke()
      end)

    pdf = Pdf.set_font(pdf, "Helvetica", size: 7)

    Enum.reduce(coords, pdf, fn {entry, index, x, y}, pdf ->
      pdf =
        pdf
        |> Pdf.set_fill_color(color)
        |> Pdf.rectangle(
          {x - @growth_point_size / 2, y - @growth_point_size / 2},
          {@growth_point_size, @growth_point_size}
        )
        |> Pdf.fill()

      if rem(index, label_every) == 0 do
        pdf
        |> Pdf.set_fill_color(@axis_label_color)
        |> Pdf.text_at({x - 10, bar_area_bottom - 10}, day_label(entry.measured_at, locale))
      else
        pdf
      end
    end)
  end

  # Weight/height have no natural "zero" axis the way daily counts do, so the
  # gridlines scale to the data's own min/max (padded to a round step)
  # rather than always starting at 0 — matches the Growth page's own
  # Chart.js trend charts (`beginAtZero: false`).
  defp nice_float_range(value, value), do: nice_float_range(value - 1, value + 1)

  defp nice_float_range(min_value, max_value) do
    range = max_value - min_value
    rough_step = range / 4
    magnitude = :math.pow(10, Float.floor(:math.log10(rough_step)))
    normalized = rough_step / magnitude

    step =
      cond do
        normalized <= 1 -> 1 * magnitude
        normalized <= 2 -> 2 * magnitude
        normalized <= 5 -> 5 * magnitude
        true -> 10 * magnitude
      end

    axis_min = Float.floor(min_value / step) * step
    axis_max = Float.ceil(max_value / step) * step
    axis_max = if axis_max == axis_min, do: axis_min + step, else: axis_max

    {axis_min, axis_max, step}
  end

  defp draw_value_gridlines(pdf, plot_x_start, bar_area_bottom, bar_area_height, axis_min, axis_max, step) do
    line_end_x = @margin + @content_width

    pdf =
      pdf
      |> Pdf.set_stroke_color(@gridline_color)
      |> Pdf.set_line_width(0.75)

    pdf =
      axis_min
      |> Stream.iterate(&(&1 + step))
      |> Enum.take_while(&(&1 <= axis_max + @float_epsilon))
      |> Enum.reduce(pdf, fn value, pdf ->
        y = bar_area_bottom + bar_area_height * (value - axis_min) / (axis_max - axis_min)
        draw_dashed_hline(pdf, plot_x_start, line_end_x, y)
      end)

    pdf
    |> Pdf.set_font("Helvetica", size: 6)
    |> Pdf.set_fill_color(@axis_label_color)
    |> draw_value_axis_labels(plot_x_start, bar_area_bottom, bar_area_height, axis_min, axis_max, step)
  end

  defp draw_value_axis_labels(pdf, plot_x_start, bar_area_bottom, bar_area_height, axis_min, axis_max, step) do
    axis_min
    |> Stream.iterate(&(&1 + step))
    |> Enum.take_while(&(&1 <= axis_max + @float_epsilon))
    |> Enum.reduce(pdf, fn value, pdf ->
      y = bar_area_bottom + bar_area_height * (value - axis_min) / (axis_max - axis_min)
      Pdf.text_at(pdf, {plot_x_start - @axis_gutter + 2, y - 2}, format_number(value))
    end)
  end

  defp format_number(value) do
    value
    |> :erlang.float_to_binary(decimals: 2)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp draw_growth_table(pdf, [], strings, _locale, top) do
    pdf
    |> Pdf.set_font("Helvetica", size: 11)
    |> Pdf.set_fill_color(:black)
    |> Pdf.text_at({@margin, top}, strings.no_measurements)
  end

  defp draw_growth_table(pdf, measurements, strings, locale, top) do
    rows =
      measurements
      |> Enum.sort_by(& &1.measured_at, {:desc, Date})
      |> Enum.map(fn m ->
        [
          format_date_only(m.measured_at, locale),
          format_measurement_value(m.weight_kg, strings.weight_unit),
          format_measurement_value(m.height_cm, strings.height_unit)
        ]
      end)

    header = [strings.date, strings.weight, strings.height]

    pdf
    |> Pdf.set_font("Helvetica", size: 10)
    |> Pdf.set_fill_color(:black)
    |> render_growth_table_pages(header, rows, top)
  end

  # Unlike the fixed, always-the-same-size totals table in `summary_pdf/4`,
  # a baby's full growth history has no upper bound on row count, so this
  # has to be able to spill onto additional pages. Rows are chunked here by
  # hand, rather than relying on `Pdf.render_table`'s own `{:continue, ...}`
  # pagination, because that continuation's "remaining" table comes back
  # with each row's cells in reversed column order (confirmed empirically —
  # Date/Weight/Height silently become Height/Weight/Date on page 2) — a
  # `pdf` library quirk, not something this app's data is doing. Chunking
  # ahead of time and rendering each page as its own fresh table sidesteps
  # that path entirely, and repeats the header on every page as a bonus.
  #
  # `@growth_table_row_height` is an empirically-measured (not
  # library-reported) estimate for this exact font size/padding, kept a
  # little above the observed ~22.4px/row so the real table — shorter than
  # estimated — always fits inside the box handed to `render_table!`,
  # guaranteeing `:complete` rather than risking a raised continuation.
  defp render_growth_table_pages(pdf, _header, [], _top), do: pdf

  defp render_growth_table_pages(pdf, header, rows, top) do
    available_height = top - @margin
    capacity = max(trunc(available_height / @growth_table_row_height) - 1, 1)
    {page_rows, rest} = Enum.split(rows, capacity)

    table =
      Pdf.Table.new([], border: 1, padding: 6)
      |> Pdf.Table.add_row(header, background: @table_header_background)
      |> Pdf.Table.add_rows(page_rows)

    pdf = Pdf.render_table!(pdf, {@margin, top}, {@content_width, available_height}, table)

    case rest do
      [] ->
        pdf

      _ ->
        pdf
        |> Pdf.add_page()
        |> Pdf.set_font("Helvetica", size: 10)
        |> Pdf.set_fill_color(:black)
        |> render_growth_table_pages(header, rest, @page_height - @margin)
    end
  end

  defp format_measurement_value(nil, _unit), do: ""
  defp format_measurement_value(value, unit), do: "#{format_number(value)}#{unit}"

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
    format_date_only(DateTime.to_date(datetime), locale)
  end

  defp format_date_only(%Date{} = date, locale) do
    case locale do
      "pt-BR" -> "#{date.day}/#{date.month}/#{date.year}"
      _ -> "#{date.month}/#{date.day}/#{date.year}"
    end
  end
end
