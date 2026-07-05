defmodule LivestokOs.AI.ResearchCorpusTest do
  use LivestokOs.AI.DataCase

  alias LivestokOs.AI.ResearchCorpus

  @embedding List.duplicate(0.1, 1536)

  describe "ingest_article/1 and search/2" do
    test "ingested article is returned by similarity search" do
      {:ok, _article} =
        ResearchCorpus.ingest_article(%{
          title: "Bovine Ketosis in Dairy Cattle",
          authors: "Smith, Jones",
          source: "PubMed",
          url: "https://pubmed.ncbi.nlm.nih.gov/12345",
          published_date: ~D[2025-06-01],
          abstract_summary: "A study on metabolic disorders in dairy cattle.",
          embedding: @embedding
        })

      results = ResearchCorpus.search(@embedding, 5)
      assert length(results) >= 1
      assert hd(results).title =~ "Bovine Ketosis"
    end
  end
end
