defmodule QrLabelSystemWeb.API.HealthControllerTest do
  use QrLabelSystemWeb.ConnCase

  describe "GET /api/health" do
    test "returns health status", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      response = json_response(conn, 200)

      assert response["status"] in ["ok", "error"]
      assert is_binary(response["timestamp"])
      assert is_map(response["checks"])
      assert response["checks"]["application"] == "ok"
      assert is_binary(response["version"])
    end
  end
end
