defmodule QrLabelSystem.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      QrLabelSystemWeb.Telemetry,
      QrLabelSystem.Repo,
      {DNSCluster, query: Application.get_env(:qr_label_system, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: QrLabelSystem.PubSub},
      {Finch, name: QrLabelSystem.Finch},
      QrLabelSystem.Cache,
      QrLabelSystem.Settings,
      QrLabelSystem.UploadDataStore,
      {Oban, Application.fetch_env!(:qr_label_system, Oban)},
      QrLabelSystemWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: QrLabelSystem.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    QrLabelSystemWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
