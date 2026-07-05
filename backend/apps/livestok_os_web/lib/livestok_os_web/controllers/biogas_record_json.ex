defmodule LivestokOsWeb.BiogasRecordJSON do
  alias LivestokOs.ZeroGrazing.BiogasRecord

  def index(%{biogas_records: records}) do
    %{data: for(r <- records, do: data(r))}
  end

  def show(%{biogas_record: record}) do
    %{data: data(record)}
  end

  defp data(%BiogasRecord{} = r) do
    %{
      id: r.id,
      farm_id: r.farm_id,
      volume_m3: r.volume_m3,
      methane_pct: r.methane_pct,
      source: r.source,
      captured_at: r.captured_at,
      metadata: r.metadata,
      inserted_at: r.inserted_at
    }
  end
end
