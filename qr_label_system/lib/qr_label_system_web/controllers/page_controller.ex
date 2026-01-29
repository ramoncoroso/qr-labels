defmodule QrLabelSystemWeb.PageController do
  use QrLabelSystemWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/designs")
    else
      render(conn, :home, layout: false)
    end
  end
end
