defmodule LivestokOs.Satellite do
  @moduledoc """
  Integration with Free Satellite Imagery (Sentinel-2 / Copernicus).

  When `SATELLITE_API_KEY` is configured, makes real HTTP calls via `Req`.
  Otherwise falls back to deterministic simulation.
  """

  @base_url "https://sh.dataspace.copernicus.eu/api/v1"

  @doc """
  Fetches the current NDVI for a coordinate pair.
  """
  def get_current_ndvi(lat, long) do
    case api_key() do
      nil -> simulate_ndvi(lat)
      key -> fetch_ndvi_from_api(lat, long, key)
    end
  end

  @doc """
  Returns a soil organic carbon factor for the given coordinate.
  Uses satellite data when available, otherwise returns a configurable default.
  """
  def get_soil_factor(lat, long) do
    case api_key() do
      nil -> Application.get_env(:livestok_os_ai, :default_soil_factor, 1.0)
      key -> fetch_soil_factor_from_api(lat, long, key)
    end
  end

  # ---------------------------------------------------------------------------
  # Real API integration via Req
  # ---------------------------------------------------------------------------

  defp fetch_ndvi_from_api(lat, long, api_key) do
    evalscript = """
    //VERSION=3
    function setup() { return { input: ["B04","B08"], output: { bands: 1 } }; }
    function evaluatePixel(s) { return [(s.B08 - s.B04) / (s.B08 + s.B04)]; }
    """

    today = Date.utc_today()
    from_date = Date.add(today, -10)

    body = %{
      input: %{
        bounds: %{
          geometry: %{
            type: "Point",
            coordinates: [long, lat]
          }
        },
        data: [%{type: "sentinel-2-l2a"}]
      },
      evalscript: evalscript,
      output: %{responses: [%{identifier: "default", format: %{type: "application/json"}}]}
    }

    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]

    case Req.post("#{@base_url}/process",
           json: body,
           headers: headers,
           params: [{"from", Date.to_iso8601(from_date)}, {"to", Date.to_iso8601(today)}],
           receive_timeout: 15_000
         ) do
      {:ok, %Req.Response{status: 200, body: resp_body}} ->
        ndvi = parse_ndvi_response(resp_body)
        {:ok, ndvi}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:satellite_api_error, status}}

      {:error, reason} ->
        {:error, {:satellite_request_failed, reason}}
    end
  rescue
    _ -> simulate_ndvi(lat)
  end

  defp fetch_soil_factor_from_api(_lat, _long, _api_key) do
    # Soil API integration placeholder — when a real soil carbon API is available
    # (e.g., SoilGrids REST), the call goes here. For now, return a reasonable default.
    Application.get_env(:livestok_os_ai, :default_soil_factor, 1.0)
  end

  defp parse_ndvi_response(body) when is_map(body) do
    case get_in(body, ["data", Access.at(0), "value"]) do
      nil -> 0.5
      val when is_number(val) -> val
      _ -> 0.5
    end
  end

  defp parse_ndvi_response(_), do: 0.5

  # ---------------------------------------------------------------------------
  # Simulation fallback
  # ---------------------------------------------------------------------------

  defp simulate_ndvi(lat) do
    if lat > 10.0 do
      {:ok, 0.25}
    else
      {:ok, 0.65}
    end
  end

  defp api_key do
    Application.get_env(:livestok_os_ai, :satellite_api_key)
  end
end
