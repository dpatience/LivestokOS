defmodule LivestokOs.Repo do
  use Ecto.Repo,
    otp_app: :livestok_os_core,
    adapter: Ecto.Adapters.Postgres
end
