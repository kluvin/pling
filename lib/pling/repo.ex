defmodule Pling.Repo do
  use Ecto.Repo,
    otp_app: :pling,
    adapter: Ecto.Adapters.SQLite3
end
