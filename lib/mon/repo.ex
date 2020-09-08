defmodule Mon.Repo do
  use Ecto.Repo,
    otp_app: :mon,
    adapter: Ecto.Adapters.Postgres
end
