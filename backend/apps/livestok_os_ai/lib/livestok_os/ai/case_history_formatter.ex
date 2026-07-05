defmodule LivestokOs.AI.CaseHistoryFormatter do
  @moduledoc """
  Turns case-history and retrieval structs into plain-language text for farmers and vets.
  """

  @source_labels %{
    cow_state_log: "Behaviour change",
    geofence_event: "Paddock / geofence",
    rotation_event: "Herd rotation",
    feed_event: "Feeding",
    biogas_record: "Biogas",
    inhibitor_dose: "Methane inhibitor",
    breeding_record: "Breeding",
    gestation: "Pregnancy",
    calving_event: "Calving",
    lactation_record: "Milking",
    alert: "Farm alert",
    carbon_sequestration: "Carbon / pasture",
    methane_avoidance_credit: "Methane credit",
    feed_efficiency: "Feed efficiency",
    deterrent_command: "Virtual fence"
  }

  @doc "Formats a full case-history map for display."
  def format_case_history(%{summary: summary, timeline: timeline}) do
    header = format_summary(summary)
    events = format_timeline(timeline)

    if events == "" do
      header
    else
      header <> "\n\n" <> events
    end
    |> String.trim()
  end

  @doc "Formats cow-own-data blob from retrieval (summary + recent slice)."
  def format_cow_own_data(%{total_events: total, categories: categories, recent: recent}) do
    lines = [
      "We have #{total} recorded event#{if total == 1, do: "", else: "s"} on file for this cow.",
      format_category_breakdown(categories),
      if(recent != [], do: "Recent records:\n" <> format_recent_slice(recent), else: nil)
    ]

    lines
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  def format_cow_own_data(data) when is_map(data), do: format_cow_own_data(normalize_own_data(data))
  def format_cow_own_data(_), do: "No detailed records available."

  @doc "Formats a single timeline entry map."
  def format_event(%{timestamp: ts, source: source, event_type: type, data: data}) do
    date_line = format_timestamp(ts)
    label = source_label(source)
    detail = format_event_detail(source, type, data)
    "- #{date_line} — #{label}: #{detail}"
  end

  def format_event(%{at: ts, source: source, type: type, data: data}) do
    format_event(%{timestamp: ts, source: source, event_type: type, data: data})
  end

  @doc "Formats classified retrieval sources for assistant replies."
  def format_sources(classified) do
    classified
    |> Enum.map(&format_classified_source/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  @doc "Short one-line labels for source types shown to users."
  def source_type_label(:cow_own_data), do: "This cow's records"
  def source_type_label(:cross_farm_pattern), do: "Similar confirmed cases"
  def source_type_label(:research_corpus), do: "Research articles"
  def source_type_label(type) when is_atom(type), do: humanize_atom(type)
  def source_type_label(type) when is_binary(type), do: String.replace(type, "_", " ") |> String.capitalize()
  def source_type_label(_), do: "Farm records"

  # ---- internals ----

  defp format_classified_source(%{source_type: :cow_own_data, data: data}) do
    format_cow_own_data(data)
  end

  defp format_classified_source(%{source_type: :cross_farm_pattern, data: data}) do
    summary = Map.get(data, :situation_summary) || Map.get(data, "situation_summary")
    answer = Map.get(data, :assistant_answer) || Map.get(data, "assistant_answer")
    confirmed = Map.get(data, :confirmed_at) || Map.get(data, "confirmed_at")

    parts =
      [
        if(summary, do: "Similar vet-confirmed case: #{summary}"),
        if(answer, do: "What was agreed: #{answer}"),
        if(confirmed, do: "Confirmed: #{format_timestamp(confirmed)}")
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: "", else: Enum.join(parts, "\n")
  end

  defp format_classified_source(%{source_type: :research_corpus, data: data}) do
    title = Map.get(data, :title) || Map.get(data, "title")
    excerpt = Map.get(data, :excerpt) || Map.get(data, "excerpt") || Map.get(data, :content)

    cond do
      title && excerpt ->
        "Research — #{title}: #{String.slice(to_string(excerpt), 0, 200)}"

      title ->
        "Research article: #{title}"

      true ->
        ""
    end
  end

  defp format_classified_source(_), do: ""

  defp format_summary(%{total_events: 0}), do: "No events recorded for this cow yet."

  defp format_summary(%{total_events: total, categories: categories, date_range: range}) do
    range_text =
      case range do
        {from, to} when not is_nil(from) and not is_nil(to) ->
          " (from #{Date.to_string(from)} to #{Date.to_string(to)})"

        _ ->
          ""
      end

    "On file: #{total} event#{if total == 1, do: "", else: "s"}#{range_text}.\n#{format_category_breakdown(categories)}"
  end

  defp format_summary(%{total_events: total, categories: categories}) do
    "On file: #{total} event#{if total == 1, do: "", else: "s"}.\n#{format_category_breakdown(categories)}"
  end

  defp format_category_breakdown(categories) when categories == %{} or categories == nil,
    do: ""

  defp format_category_breakdown(categories) do
    breakdown =
      categories
      |> Enum.map(fn {source, count} ->
        "#{source_label(source)} (#{count})"
      end)
      |> Enum.join(", ")

    "Includes: #{breakdown}."
  end

  defp format_timeline(timeline) do
    timeline
    |> Enum.take(-8)
    |> Enum.map(&format_event/1)
    |> Enum.join("\n")
  end

  defp format_recent_slice(recent) do
    recent
    |> Enum.map(&format_event/1)
    |> Enum.join("\n")
  end

  defp format_event_detail(:feed_event, _type, data) do
    feed = fetch(data, :feed_type, "feed")
    qty = fetch(data, :quantity_kg)
    inhibitor = fetch(data, :inhibitor_added)

    base = if qty, do: "#{qty} kg #{feed}", else: feed

    if inhibitor in [true, "true"],
      do: "#{base} (methane inhibitor added to ration)",
      else: base
  end

  defp format_event_detail(:inhibitor_dose, _type, data) do
    type = fetch(data, :type, "inhibitor")
    dose = fetch(data, :dose_mg)
    eff = fetch(data, :effectiveness_pct)

    parts =
      [
        if(dose, do: "#{dose} mg #{type}"),
        if(eff, do: "#{eff}% reported effectiveness")
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: "#{type} dose recorded", else: Enum.join(parts, ", ")
  end

  defp format_event_detail(:alert, type, data) do
    msg = fetch(data, :message)
    severity = fetch(data, :severity)
    resolved = fetch(data, :resolved)

    parts =
      [
        humanize_atom(type),
        if(severity, do: "(#{severity})"),
        if(msg, do: msg),
        if(resolved in [true, "true"], do: "— resolved")
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, " ")
  end

  defp format_event_detail(:lactation_record, _type, data) do
    yield = fetch(data, :yield_liters)
    fat = fetch(data, :fat_pct)
    protein = fetch(data, :protein_pct)

    parts =
      [
        if(yield, do: "#{yield} L milk"),
        if(fat, do: "#{fat}% fat"),
        if(protein, do: "#{protein}% protein")
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: "Milking recorded", else: Enum.join(parts, ", ")
  end

  defp format_event_detail(:breeding_record, _type, data) do
    method = fetch(data, :method)
    outcome = fetch(data, :outcome)
    sire = fetch(data, :sire_reference)

    parts =
      [
        if(method, do: "Method: #{humanize_atom(method)}"),
        if(outcome, do: "Outcome: #{humanize_atom(outcome)}"),
        if(sire, do: "Sire: #{sire}")
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: "Breeding event", else: Enum.join(parts, ". ")
  end

  defp format_event_detail(:gestation, _type, data) do
    status = fetch(data, :status)
    expected = fetch(data, :expected_calving)
    actual = fetch(data, :actual_calving)

    parts =
      [
        if(status, do: "Status: #{humanize_atom(status)}"),
        if(expected, do: "Expected calving: #{format_date(expected)}"),
        if(actual, do: "Calved: #{format_date(actual)}")
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: "Pregnancy record", else: Enum.join(parts, ". ")
  end

  defp format_event_detail(:calving_event, _type, data) do
    diff = fetch(data, :difficulty)
    weight = fetch(data, :birth_weight_kg)

    parts =
      [
        if(diff, do: "#{humanize_atom(diff)} calving"),
        if(weight, do: "Calf weight #{weight} kg")
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: "Calving recorded", else: Enum.join(parts, ", ")
  end

  defp format_event_detail(:geofence_event, type, data) do
    payload = Map.get(data, :payload) || Map.get(data, "payload") || %{}
    lat = Map.get(payload, :latitude) || Map.get(payload, "latitude")
    lng = Map.get(payload, :longitude) || Map.get(payload, "longitude")

    loc =
      if lat && lng,
        do: " near #{Float.round(lat * 1.0, 4)}, #{Float.round(lng * 1.0, 4)}",
        else: ""

    "#{humanize_atom(type)}#{loc}"
  end

  defp format_event_detail(:cow_state_log, _type, data) do
    from = fetch(data, :from)
    to = fetch(data, :to)
    "Changed from #{humanize_atom(from)} to #{humanize_atom(to)}"
  end

  defp format_event_detail(:rotation_event, _type, data) do
    paddock = fetch(data, :paddock_id)
    if paddock, do: "Herd left paddock ##{paddock}", else: "Herd rotation recorded"
  end

  defp format_event_detail(:biogas_record, _type, data) do
    vol = fetch(data, :volume_m3)
    methane = fetch(data, :methane_pct)

    parts =
      [
        if(vol, do: "#{vol} m³ captured"),
        if(methane, do: "#{methane}% methane")
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: "Biogas capture", else: Enum.join(parts, ", ")
  end

  defp format_event_detail(:carbon_sequestration, _type, data) do
    carbon = fetch(data, :carbon_tco2e)
    paddock = fetch(data, :paddock_id)

    parts =
      [
        if(carbon, do: "#{carbon} tCO₂e sequestered"),
        if(paddock, do: "paddock ##{paddock}")
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, " on ")
  end

  defp format_event_detail(:methane_avoidance_credit, _type, data) do
    credit = fetch(data, :credit_tco2e)
    avoided = fetch(data, :methane_avoided_kg)

    parts =
      [
        if(avoided, do: "#{avoided} kg methane avoided"),
        if(credit, do: "#{credit} tCO₂e credit")
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: "Methane avoidance credit", else: Enum.join(parts, ", ")
  end

  defp format_event_detail(:feed_efficiency, _type, data) do
    idx = fetch(data, :feed_efficiency_index)
    hours = fetch(data, :cumulative_grazing_hours)

    parts =
      [
        if(idx, do: "efficiency index #{idx}"),
        if(hours, do: "#{hours} grazing hours")
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: "Feed efficiency calculation", else: Enum.join(parts, ", ")
  end

  defp format_event_detail(:deterrent_command, type, data) do
    ack = fetch(data, :acknowledged_at)
    status = if ack, do: "acknowledged by collar", else: "pending on collar"
    "#{humanize_atom(type)} — #{status}"
  end

  defp format_event_detail(_source, type, data) when is_map(data) and map_size(data) > 0 do
    data
    |> Enum.map(fn {k, v} -> "#{humanize_atom(k)}: #{format_value(v)}" end)
    |> Enum.join(", ")
    |> then(fn text -> if text == "", do: humanize_atom(type), else: text end)
  end

  defp format_event_detail(_source, type, _data), do: humanize_atom(type)

  defp source_label(source) when is_atom(source), do: Map.get(@source_labels, source, humanize_atom(source))

  defp source_label(source) when is_binary(source) do
    case Map.get(@source_labels, String.to_existing_atom(source)) do
      nil -> String.replace(source, "_", " ") |> String.capitalize()
      label -> label
    end
  rescue
    ArgumentError -> String.replace(source, "_", " ") |> String.capitalize()
  end

  defp normalize_own_data(data) do
    %{
      total_events: fetch(data, :total_events) || 0,
      categories: fetch(data, :categories) || %{},
      recent: fetch(data, :recent) || []
    }
  end

  defp fetch(map, key, default \\ nil) do
    Map.get(map, key) || Map.get(map, to_string(key)) || default
  end

  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d %b %Y, %H:%M UTC")
  end

  defp format_timestamp(%NaiveDateTime{} = dt) do
    dt |> DateTime.from_naive!("Etc/UTC") |> format_timestamp()
  end

  defp format_timestamp(%Date{} = d), do: Date.to_string(d)
  defp format_timestamp(other) when not is_nil(other), do: to_string(other)
  defp format_timestamp(_), do: "Unknown date"

  defp format_date(%Date{} = d), do: Date.to_string(d)
  defp format_date(other) when not is_nil(other), do: to_string(other)
  defp format_date(_), do: nil

  defp format_value(v) when is_atom(v), do: humanize_atom(v)
  defp format_value(v) when is_binary(v), do: v
  defp format_value(v) when is_number(v), do: to_string(v)
  defp format_value(true), do: "yes"
  defp format_value(false), do: "no"
  defp format_value(nil), do: "not recorded"
  defp format_value(v), do: inspect(v, limit: 40)

  defp humanize_atom(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp humanize_atom(str) when is_binary(str), do: humanize_atom(String.to_atom(str))
end
