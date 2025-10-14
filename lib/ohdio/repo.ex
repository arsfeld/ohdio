defmodule Ohdio.Repo do
  use Ecto.Repo,
    otp_app: :ohdio,
    adapter: Ecto.Adapters.SQLite3
end
