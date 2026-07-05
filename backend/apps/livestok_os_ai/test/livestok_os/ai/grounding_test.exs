defmodule LivestokOs.AI.GroundingTest do
  use ExUnit.Case, async: true

  alias LivestokOs.AI.Grounding

  describe "classify_sources/1" do
    test "tags case history as cow_own_data" do
      results = [%{source: :case_history, data: %{timeline_count: 10}}]
      classified = Grounding.classify_sources(results)
      assert [%{source_type: :cow_own_data}] = classified
    end

    test "tags confirmed cases as cross_farm_pattern" do
      results = [
        %{
          source: :confirmed_case,
          data: %{farm_id: 1, owner_name: "Secret", farm_name: "Hidden Farm", summary: "case"}
        }
      ]

      classified = Grounding.classify_sources(results)
      assert [%{source_type: :cross_farm_pattern, data: data}] = classified
      refute Map.has_key?(data, :farm_id)
      refute Map.has_key?(data, :owner_name)
      refute Map.has_key?(data, :farm_name)
    end

    test "tags research as research_corpus" do
      results = [%{source: :research, data: %{title: "Study on bovine ketosis"}}]
      classified = Grounding.classify_sources(results)
      assert [%{source_type: :research_corpus}] = classified
    end
  end

  describe "privacy filter" do
    test "cross-farm results have no farm_id, owner_name, or farm_name" do
      results = [
        %{
          source: :confirmed_case,
          data: %{
            farm_id: 99,
            owner_name: "John Doe",
            farm_name: "Doe Ranch",
            situation: "lameness"
          }
        }
      ]

      [classified] = Grounding.classify_sources(results)
      refute Map.has_key?(classified.data, :farm_id)
      refute Map.has_key?(classified.data, :owner_name)
      refute Map.has_key?(classified.data, :farm_name)
      assert classified.data.situation == "lameness"
    end
  end

  describe "handle_insufficient_data/2" do
    test "returns insufficient_data: true with no fabricated answers" do
      result = Grounding.handle_insufficient_data("What's wrong with this cow?", [])

      assert result.insufficient_data == true
      assert result.message =~ "not yet available"
      assert is_list(result.recommended_next_steps)
      assert length(result.recommended_next_steps) > 0
      refute result.message =~ "likely"
      refute result.message =~ "probably"
    end
  end

  describe "build_response_with_attribution/2" do
    test "wraps response with source attributions" do
      sources = [
        %{source_type: :cow_own_data, data: %{}},
        %{source_type: :research_corpus, data: %{}}
      ]

      result = Grounding.build_response_with_attribution(sources, "Some LLM response")
      assert result.response == "Some LLM response"
      assert is_list(result.attributions)
    end
  end
end
