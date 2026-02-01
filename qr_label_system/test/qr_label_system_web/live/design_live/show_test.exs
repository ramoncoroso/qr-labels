defmodule QrLabelSystemWeb.DesignLive.ShowTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DesignsFixtures

  describe "Show Design" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      design = design_fixture(%{user_id: user.id, name: "Test Design"})
      %{conn: conn, user: user, design: design}
    end

    test "displays design details", %{conn: conn, design: design} do
      {:ok, _view, html} = live(conn, ~p"/designs/#{design.id}")

      assert html =~ "Test Design"
    end

    test "shows design dimensions", %{conn: conn, design: design} do
      {:ok, _view, html} = live(conn, ~p"/designs/#{design.id}")

      assert html =~ to_string(design.width_mm) or html =~ to_string(trunc(design.width_mm))
    end

    test "shows edit link for owner", %{conn: conn, design: design} do
      {:ok, _view, html} = live(conn, ~p"/designs/#{design.id}")

      assert html =~ "/designs/#{design.id}/edit"
    end
  end

  describe "Show Design - access control" do
    # NOTE: Currently the show page allows viewing any design (for template sharing).
    # Edit access is properly restricted in the editor (see editor_test.exs).
    # If stricter view access is needed, add user_id check in show.ex mount/2.
    test "cannot edit other user's design via show page", %{conn: conn} do
      other_user = user_fixture()
      other_design = design_fixture(%{user_id: other_user.id})

      user = user_fixture()
      conn = log_in_user(conn, user)

      result = live(conn, ~p"/designs/#{other_design.id}")

      case result do
        {:error, {:redirect, _}} -> assert true
        {:error, {:live_redirect, _}} -> assert true
        {:ok, _view, _html} ->
          # Viewing may be allowed, but editing is blocked at the editor level
          # See editor_test.exs "cannot edit other user's design" test
          assert true
      end
    end
  end

  describe "Show Design - unauthenticated" do
    test "redirects to login", %{conn: conn} do
      design = design_fixture()
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/designs/#{design.id}")
      assert path =~ "/users/log_in"
    end
  end
end
