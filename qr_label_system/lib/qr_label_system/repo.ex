defmodule QrLabelSystem.Repo do
  use Ecto.Repo,
    otp_app: :qr_label_system,
    adapter: Ecto.Adapters.Postgres
end
