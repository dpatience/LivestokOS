defmodule LivestokOs.AI.CaseHistoryFormatterTest do
  use ExUnit.Case, async: true

  alias LivestokOs.AI.CaseHistoryFormatter

  test "formats cow own data without inspect dumps" do
    data = %{
      total_events: 2,
      categories: %{inhibitor_dose: 1, feed_event: 1},
      recent: [
        %{
          at: ~U[2026-07-05 08:11:13Z],
          source: :inhibitor_dose,
          type: "inhibitor_administration",
          data: %{type: "Other", dose_mg: 200.0, effectiveness_pct: nil}
        },
        %{
          at: ~U[2026-07-05 08:11:27Z],
          source: :feed_event,
          type: "feeding",
          data: %{feed_type: "Silage", quantity_kg: 4.0, inhibitor_added: false}
        }
      ]
    }

    text = CaseHistoryFormatter.format_cow_own_data(data)

    assert text =~ "2 recorded events"
    assert text =~ "Methane inhibitor"
    assert text =~ "Feeding"
    assert text =~ "200 mg Other"
    assert text =~ "4.0 kg Silage"
    refute text =~ "%{"
    refute text =~ "inspect"
  end

  test "formats classified cow_own_data source" do
    classified = [
      %{
        source_type: :cow_own_data,
        data: %{
          total_events: 1,
          categories: %{feed_event: 1},
          recent: [
            %{
              at: ~U[2026-07-05 10:00:00Z],
              source: :feed_event,
              type: "feeding",
              data: %{feed_type: "Hay", quantity_kg: 2.5, inhibitor_added: false}
            }
          ]
        }
      }
    ]

    text = CaseHistoryFormatter.format_sources(classified)

    assert text =~ "1 recorded event"
    assert text =~ "2.5 kg Hay"
  end

  test "local responder uses plain language for recorded data" do
    retrieval = %{
      case_history: %{
        summary: %{total_events: 2, categories: %{feed_event: 1, inhibitor_dose: 1}},
        timeline: []
      },
      confirmed_cases: [],
      sources: [%{source: :case_history, data: %{total_events: 2, categories: %{}, recent: []}}]
    }

    classified = [
      %{
        source_type: :cow_own_data,
        data: %{
          total_events: 2,
          categories: %{feed_event: 1, inhibitor_dose: 1},
          recent: [
            %{
              at: ~U[2026-07-05 08:11:27Z],
              source: :feed_event,
              type: "feeding",
              data: %{feed_type: "Silage", quantity_kg: 4.0, inhibitor_added: false}
            }
          ]
        }
      }
    ]

    assert {:ok, %{response: response}} =
             LivestokOs.AI.LocalResponder.respond("why is she quiet?", retrieval, classified)

    assert response =~ "Here's what we have recorded"
    assert response =~ "reasoning model"
    assert response =~ "Silage"
    refute response =~ "cow_own_data"
    refute response =~ "%{"
  end
end
