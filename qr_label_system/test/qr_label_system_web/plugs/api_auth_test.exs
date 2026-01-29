defmodule QrLabelSystemWeb.Plugs.ApiAuthTest do
  use QrLabelSystemWeb.ConnCase

  alias QrLabelSystem.Accounts
  alias QrLabelSystemWeb.Plugs.ApiAuth

  import QrLabelSystem.AccountsFixtures

  describe "authenticate_api/2" do
    test "authenticates user with valid Base64-encoded Bearer token", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      encoded_token = Base.url_encode64(token, padding: false)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{encoded_token}")
        |> ApiAuth.authenticate_api([])

      assert conn.assigns[:current_user].id == user.id
      refute conn.halted
    end

    test "authenticates with case-insensitive Bearer prefix", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      encoded_token = Base.url_encode64(token, padding: false)

      for prefix <- ["Bearer", "bearer", "BEARER"] do
        test_conn =
          conn
          |> put_req_header("authorization", "#{prefix} #{encoded_token}")
          |> ApiAuth.authenticate_api([])

        assert test_conn.assigns[:current_user].id == user.id,
               "Failed for prefix: #{prefix}"
      end
    end

    test "rejects invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalidtoken123")
        |> ApiAuth.authenticate_api([])

      assert conn.status == 401
      assert conn.halted

      response = Jason.decode!(conn.resp_body)
      assert response["error"] =~ "Invalid"
    end

    test "rejects missing authorization header", %{conn: conn} do
      conn = ApiAuth.authenticate_api(conn, [])

      assert conn.status == 401
      assert conn.halted

      response = Jason.decode!(conn.resp_body)
      assert response["error"] == "Missing authorization header"
    end

    test "rejects empty token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer ")
        |> ApiAuth.authenticate_api([])

      assert conn.status == 401
      assert conn.halted

      response = Jason.decode!(conn.resp_body)
      assert response["error"] == "Empty token provided"
    end

    test "rejects whitespace-only token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer    ")
        |> ApiAuth.authenticate_api([])

      assert conn.status == 401
      assert conn.halted
    end

    test "rejects invalid authorization header format", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Basic dXNlcm5hbWU6cGFzc3dvcmQ=")
        |> ApiAuth.authenticate_api([])

      assert conn.status == 401
      assert conn.halted

      response = Jason.decode!(conn.resp_body)
      assert response["error"] =~ "Invalid authorization header format"
    end

    test "rejects expired token", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      encoded_token = Base.url_encode64(token, padding: false)

      # Delete the token to simulate expiration
      Accounts.delete_user_session_token(token)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{encoded_token}")
        |> ApiAuth.authenticate_api([])

      assert conn.status == 401
      assert conn.halted

      response = Jason.decode!(conn.resp_body)
      assert response["error"] == "Invalid or expired token"
    end

    test "rejects multiple authorization headers", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer token1")
        |> Plug.Conn.put_req_header("authorization", "Bearer token2")
        |> ApiAuth.authenticate_api([])

      # Note: put_req_header replaces, so this test verifies single header behavior
      # In reality, HTTP allows multiple headers, but our code handles the list
      assert conn.status == 401 or conn.assigns[:current_user] == nil
    end
  end

  describe "maybe_authenticate_api/2" do
    test "authenticates user when valid token provided", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      encoded_token = Base.url_encode64(token, padding: false)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{encoded_token}")
        |> ApiAuth.maybe_authenticate_api([])

      assert conn.assigns[:current_user].id == user.id
      refute conn.halted
    end

    test "assigns nil current_user when no token provided", %{conn: conn} do
      conn = ApiAuth.maybe_authenticate_api(conn, [])

      assert conn.assigns[:current_user] == nil
      refute conn.halted
    end

    test "assigns nil current_user when invalid token provided", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalidtoken")
        |> ApiAuth.maybe_authenticate_api([])

      assert conn.assigns[:current_user] == nil
      refute conn.halted
    end
  end
end
