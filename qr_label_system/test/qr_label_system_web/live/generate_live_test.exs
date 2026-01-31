defmodule QrLabelSystemWeb.GenerateLiveTest do
  use QrLabelSystemWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DesignsFixtures

  describe "Index (mode selection)" do
    test "renders mode selection page", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/generate")

      assert html =~ "Generar Etiquetas"
      assert html =~ "Etiqueta Única"
      assert html =~ "Múltiples Etiquetas"
    end

    test "shows links to both flows", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/generate")

      # Verify navigation links exist
      assert has_element?(lv, "a[href='/generate/single']")
      assert has_element?(lv, "a[href='/generate/data']")
    end
  end

  describe "SingleSelect" do
    test "renders single label design selection", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/generate/single")

      assert html =~ "Etiqueta Única"
      assert html =~ "Nuevo Diseño"
    end

    test "shows user's designs", %{conn: conn} do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id, name: "Test Design"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/generate/single")

      assert html =~ design.name
    end
  end

  describe "DataFirst" do
    test "renders data upload page", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/generate/data")

      assert html =~ "Cargar datos para etiquetas"
      assert html =~ "Excel"
      assert html =~ "CSV"
      assert html =~ "Pegar datos"
    end

    test "shows method selection cards", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/generate/data")

      # Click on paste method
      html = lv |> element("button[phx-value-method='paste']") |> render_click()

      assert html =~ "Pegar datos desde Excel"
    end
  end

  describe "SingleLabel" do
    test "renders single label print page", %{conn: conn} do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id, name: "Test Design"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/generate/single/#{design.id}")

      assert html =~ "Imprimir Etiqueta"
      assert html =~ "Cantidad de etiquetas"
      assert html =~ design.name
    end

    test "can update quantity", %{conn: conn} do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/generate/single/#{design.id}")

      # Click the +1 button
      html = lv |> element("button[phx-value-quantity='2']") |> render_click()

      # The quantity should be updated in the input
      assert html =~ "value=\"2\""
    end

    test "redirects if design belongs to another user", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      design = design_fixture(%{user_id: other_user.id})

      conn = log_in_user(conn, user)

      assert {:error, {:live_redirect, %{to: "/generate/single"}}} =
               live(conn, ~p"/generate/single/#{design.id}")
    end
  end

  describe "DesignSelect" do
    test "redirects to data page if no data in flash", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:live_redirect, %{to: "/generate/data"}}} =
               live(conn, ~p"/generate/design")
    end
  end
end
