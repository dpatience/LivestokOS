defmodule LivestokOsWeb.Router do
  use LivestokOsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug LivestokOsWeb.Plugs.AuthPipeline
  end

  pipeline :farm_scoped do
    plug LivestokOsWeb.Plugs.FarmScope
  end

  pipeline :rate_limit_auth do
    plug LivestokOsWeb.Plugs.RateLimiter,
      limit: 10,
      window_seconds: 60,
      key: :ip
  end

  pipeline :rate_limit_ingest do
    plug LivestokOsWeb.Plugs.RateLimiter,
      limit: 300,
      window_seconds: 60,
      key: :ip
  end

  # Public health check — no auth required.
  scope "/api", LivestokOsWeb do
    pipe_through :api

    get "/health", HealthController, :show
  end

  # Public endpoints — no JWT required (auth/register, LoRaWAN gateway ingest).
  # Rate limited to prevent brute-force and ingestion abuse.
  scope "/api", LivestokOsWeb do
    pipe_through [:api, :rate_limit_auth]

    post "/register", AuthController, :register
    post "/login", AuthController, :login
  end

  scope "/api", LivestokOsWeb do
    pipe_through [:api, :rate_limit_ingest]

    # LoRaWAN gateway ingest (authenticated via gateway_eui, not JWT)
    post "/lorawan/ingest", LorawanController, :ingest
  end

  # Protected + Farm-scoped endpoints
  scope "/api", LivestokOsWeb do
    pipe_through [:api, :authenticated, :farm_scoped]

    # Animals / Cows
    get "/animals", CowController, :index
    post "/animals", CowController, :create
    get "/animals/:id", CowController, :show
    put "/animals/:id", CowController, :update
    delete "/animals/:id", CowController, :delete

    # Inventory
    resources "/farms", FarmController, except: [:new, :edit]
    resources "/cows", CowController, except: [:new, :edit]
    post "/cows/:id/analyze", CowController, :analyze
    resources "/devices", DeviceController, except: [:new, :edit]

    # Telemetry
    resources "/sensor_readings", SensorReadingController, except: [:new, :edit]
    post "/telemetry/ingest", TelemetryController, :ingest
    post "/telemetry/ingest/batch", TelemetryController, :ingest_batch
    get "/telemetry/summary", TelemetryController, :summary

    # Operations
    resources "/grazing_events", GrazingEventController, except: [:new, :edit]
    resources "/alerts", AlertController, only: [:index, :update]

    # Digital Twin (per-cow)
    get "/cows/:cow_id/twin", DigitalTwinController, :show
    get "/cows/:cow_id/behavior", DigitalTwinController, :behavior_history
    get "/cows/:cow_id/state_logs", DigitalTwinController, :state_logs
    get "/digital_twins/active", DigitalTwinController, :active

    # Satellite History
    get "/satellite/records", SatelliteController, :index
    get "/satellite/ndvi", SatelliteController, :ndvi_series
    get "/satellite/gallery", SatelliteController, :gallery
    post "/satellite/capture", SatelliteController, :capture

    # Zero Grazing / Indoor module
    resources "/feed_events", FeedEventController, except: [:new, :edit]
    resources "/biogas_records", BiogasRecordController, except: [:new, :edit]
    resources "/inhibitor_doses", InhibitorDoseController, except: [:new, :edit]

    # Infrastructure (geofences / virtual fences)
    resources "/geofences", GeofenceController, except: [:new, :edit]
    get "/geofence_events", GeofenceEventController, :index

    # Virtual-fence deterrent commands (collar firmware polling — LoRaWAN uplink-only)
    get "/farms/:farm_id/cows/:cow_id/pending_deterrent_commands",
        DeterrentCommandController,
        :pending

    post "/farms/:farm_id/cows/:cow_id/deterrent_commands/:id/acknowledge",
         DeterrentCommandController,
         :acknowledge

    # Stage 4C: Digital Passport per animal (generated on request)
    get "/farms/:farm_id/cows/:cow_id/digital_passport",
        DigitalPassportController,
        :show

    # Admin-only endpoints
    get "/admin/farms", AdminController, :list_farms
    delete "/admin/cows/:cow_id/history", AdminController, :reset_cow_history
    delete "/admin/farms/:farm_id/telemetry", AdminController, :reset_farm_telemetry
  end
end
