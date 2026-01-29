defmodule QrLabelSystemWeb.BatchLive.New do
  use QrLabelSystemWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/generate")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Redirigiendo...</div>
    """
  end
end
