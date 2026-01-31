defmodule QrLabelSystemWeb.DataSourceControllerTest do
  use QrLabelSystemWeb.ConnCase

  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DataSourcesFixtures

  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "upload/2" do
    test "redirects to details with valid file", %{conn: conn} do
      # Create a temporary test file
      path = Path.join(System.tmp_dir!(), "test_upload.xlsx")
      File.write!(path, "fake xlsx content")

      upload = %Plug.Upload{
        path: path,
        filename: "test_data.xlsx",
        content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      }

      conn = post(conn, ~p"/data-sources/upload", %{"file" => upload})

      assert redirected_to(conn) == ~p"/data-sources/new/details"
      assert get_session(conn, :uploaded_file_path) != nil
      assert get_session(conn, :uploaded_file_name) == "test_data.xlsx"
      assert get_session(conn, :detected_type) == "excel"
      assert get_session(conn, :suggested_name) == "test_data"

      File.rm!(path)
    end

    test "detects csv file type", %{conn: conn} do
      path = Path.join(System.tmp_dir!(), "test_upload.csv")
      File.write!(path, "a,b,c\n1,2,3")

      upload = %Plug.Upload{
        path: path,
        filename: "data.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/data-sources/upload", %{"file" => upload})

      assert get_session(conn, :detected_type) == "csv"

      File.rm!(path)
    end

    test "redirects with error when no file", %{conn: conn} do
      conn = post(conn, ~p"/data-sources/upload", %{})

      assert redirected_to(conn) == ~p"/data-sources/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "selecciona un archivo"
    end
  end

  # Note: Data source creation is handled via LiveView
  # These tests focus on the controller delete action which is functional

  describe "delete/2" do
    test "deletes own data source", %{conn: conn, user: user} do
      data_source = data_source_fixture(%{user_id: user.id})

      conn = delete(conn, ~p"/data-sources/#{data_source.id}")

      assert redirected_to(conn) == ~p"/data-sources"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "eliminados exitosamente"
    end

    test "cannot delete other user's data source", %{conn: conn} do
      other_user = user_fixture()
      data_source = data_source_fixture(%{user_id: other_user.id})

      conn = delete(conn, ~p"/data-sources/#{data_source.id}")

      assert redirected_to(conn) == ~p"/data-sources"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "No tienes permiso"
    end
  end
end
