defmodule D9s.Repo do
  use Ecto.Repo,
    otp_app: :d9s,
    adapter: Ecto.Adapters.SQLite3
end
