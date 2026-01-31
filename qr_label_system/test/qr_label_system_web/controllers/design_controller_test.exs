defmodule QrLabelSystemWeb.DesignControllerTest do
  use QrLabelSystemWeb.ConnCase

  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DesignsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  # Note: Design creation may be handled by LiveView instead of controller
  # depending on routing configuration. These tests verify the controller
  # behavior when the route exists.

  describe "delete/2" do
    test "deletes own design", %{conn: conn, user: user} do
      design = design_fixture(%{user_id: user.id})

      conn = delete(conn, ~p"/designs/#{design.id}")

      assert redirected_to(conn) == ~p"/designs"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "eliminado exitosamente"

      assert_raise Ecto.NoResultsError, fn ->
        QrLabelSystem.Designs.get_design!(design.id)
      end
    end

    test "cannot delete other user's design", %{conn: conn} do
      other_user = user_fixture()
      design = design_fixture(%{user_id: other_user.id})

      conn = delete(conn, ~p"/designs/#{design.id}")

      assert redirected_to(conn) == ~p"/designs"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "No tienes permiso"

      # Design should still exist
      assert QrLabelSystem.Designs.get_design!(design.id) != nil
    end
  end
end
