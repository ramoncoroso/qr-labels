defmodule QrLabelSystemWeb.API.HealthControllerTest do
  use QrLabelSystemWeb.ConnCase

  describe "GET /api/health" do
    test "returns health status with all required fields", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      response = json_response(conn, 200)

      # Verify required fields exist
      assert response["status"] in ["ok", "error"]
      assert is_binary(response["timestamp"])
      assert is_map(response["checks"])
      assert response["checks"]["application"] == "ok"
      assert is_binary(response["version"])
    end

    test "does not require authentication", %{conn: conn} do
      # Health check should work without any auth headers
      conn = get(conn, ~p"/api/health")
      assert json_response(conn, 200)
    end

    test "returns proper content type", %{conn: conn} do
      conn = get(conn, ~p"/api/health")

      assert get_resp_header(conn, "content-type") |> List.first() =~ "application/json"
    end

    test "returns valid ISO8601 timestamp", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      response = json_response(conn, 200)

      # Timestamp should be parseable
      assert {:ok, _, _} = DateTime.from_iso8601(response["timestamp"])
    end

    test "returns correct version format", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      response = json_response(conn, 200)

      # Version should be a semantic version string
      assert response["version"] =~ ~r/^\d+\.\d+\.\d+$/
    end

    test "includes database check in response", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      response = json_response(conn, 200)

      # Should have database check (ok or error)
      assert response["checks"]["database"] in ["ok", "error"]
    end
  end
end
