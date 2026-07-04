defmodule LivestokOs.Repo do
  use Ecto.Repo,
    otp_app: :livestok_os,
    adapter: Ecto.Adapters.Postgres
end
