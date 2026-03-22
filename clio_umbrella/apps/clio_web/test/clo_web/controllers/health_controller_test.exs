defmodule CloWeb.HealthControllerTest do
  use CloWeb.ConnCase, async: true

  describe "GET /api/health" do
    test "returns ok status", %{conn: conn} do
      conn = get(conn, "/api/health")
      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert Map.has_key?(response, "timestamp")
    end
  end
end
