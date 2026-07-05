defmodule LivestokOsWeb.InhibitorDoseJSON do
  alias LivestokOs.ZeroGrazing.InhibitorDose

  def index(%{inhibitor_doses: doses}) do
    %{data: for(d <- doses, do: data(d))}
  end

  def show(%{inhibitor_dose: dose}) do
    %{data: data(dose)}
  end

  defp data(%InhibitorDose{} = d) do
    %{
      id: d.id,
      cow_id: d.cow_id,
      inhibitor_type: d.inhibitor_type,
      dose_mg: d.dose_mg,
      administered_at: d.administered_at,
      effectiveness_pct: d.effectiveness_pct,
      notes: d.notes,
      inserted_at: d.inserted_at
    }
  end
end
