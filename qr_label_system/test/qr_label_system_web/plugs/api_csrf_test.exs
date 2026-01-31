defmodule QrLabelSystemWeb.Plugs.ApiCsrfTest do
  use QrLabelSystemWeb.ConnCase

  alias QrLabelSystemWeb.Plugs.ApiCsrf

  describe "call/2 - safe methods" do
    test "allows GET requests without CSRF token" do
      conn = build_conn(:get, "/api/resource")
      conn = ApiCsrf.call(conn, [])

      refute conn.halted
    end

    test "allows HEAD requests without CSRF token" do
      conn = build_conn(:head, "/api/resource")
      conn = ApiCsrf.call(conn, [])

      refute conn.halted
    end

    test "allows OPTIONS requests without CSRF token" do
      conn = build_conn(:options, "/api/resource")
      conn = ApiCsrf.call(conn, [])

      refute conn.halted
    end

    test "sets CSRF cookie on GET request if not present" do
      conn = build_conn(:get, "/api/resource")
      conn = ApiCsrf.call(conn, [])

      cookie = conn.resp_cookies["_csrf_token"]
      assert cookie != nil
      assert cookie.value != nil
    end

    test "preserves existing CSRF cookie on GET request" do
      conn =
        build_conn(:get, "/api/resource")
        |> put_req_cookie("_csrf_token", "existing_token")

      conn = ApiCsrf.call(conn, [])

      # Should not set new cookie
      refute Map.has_key?(conn.resp_cookies, "_csrf_token")
    end
  end

  describe "call/2 - mutating methods" do
    test "rejects POST without CSRF cookie" do
      conn =
        build_conn(:post, "/api/resource")
        |> put_req_header("content-type", "application/json")

      conn = ApiCsrf.call(conn, [])

      assert conn.halted
      assert conn.status == 403
      assert Jason.decode!(conn.resp_body)["code"] == "csrf_error"
    end

    test "rejects POST without CSRF header" do
      conn =
        build_conn(:post, "/api/resource")
        |> put_req_cookie("_csrf_token", "test_token")
        |> put_req_header("content-type", "application/json")

      conn = ApiCsrf.call(conn, [])

      assert conn.halted
      assert conn.status == 403
      assert Jason.decode!(conn.resp_body)["error"] =~ "Missing X-CSRF-Token"
    end

    test "rejects POST with mismatched tokens" do
      conn =
        build_conn(:post, "/api/resource")
        |> put_req_cookie("_csrf_token", "cookie_token")
        |> put_req_header("x-csrf-token", "different_token")
        |> put_req_header("content-type", "application/json")

      conn = ApiCsrf.call(conn, [])

      assert conn.halted
      assert conn.status == 403
      assert Jason.decode!(conn.resp_body)["error"] =~ "Invalid CSRF token"
    end

    test "allows POST with matching tokens" do
      token = ApiCsrf.generate_token()

      conn =
        build_conn(:post, "/api/resource")
        |> put_req_cookie("_csrf_token", token)
        |> put_req_header("x-csrf-token", token)
        |> put_req_header("content-type", "application/json")

      conn = ApiCsrf.call(conn, [])

      refute conn.halted
    end

    test "allows PUT with matching tokens" do
      token = ApiCsrf.generate_token()

      conn =
        build_conn(:put, "/api/resource/1")
        |> put_req_cookie("_csrf_token", token)
        |> put_req_header("x-csrf-token", token)
        |> put_req_header("content-type", "application/json")

      conn = ApiCsrf.call(conn, [])

      refute conn.halted
    end

    test "allows PATCH with matching tokens" do
      token = ApiCsrf.generate_token()

      conn =
        build_conn(:patch, "/api/resource/1")
        |> put_req_cookie("_csrf_token", token)
        |> put_req_header("x-csrf-token", token)
        |> put_req_header("content-type", "application/json")

      conn = ApiCsrf.call(conn, [])

      refute conn.halted
    end

    test "allows DELETE with matching tokens" do
      token = ApiCsrf.generate_token()

      conn =
        build_conn(:delete, "/api/resource/1")
        |> put_req_cookie("_csrf_token", token)
        |> put_req_header("x-csrf-token", token)

      conn = ApiCsrf.call(conn, [])

      refute conn.halted
    end
  end

  describe "generate_token/0" do
    test "generates a token" do
      token = ApiCsrf.generate_token()
      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "generates unique tokens" do
      token1 = ApiCsrf.generate_token()
      token2 = ApiCsrf.generate_token()
      assert token1 != token2
    end
  end

  describe "get_csrf_token/1" do
    test "returns token from cookie" do
      conn =
        build_conn(:get, "/")
        |> put_req_cookie("_csrf_token", "my_token")

      assert ApiCsrf.get_csrf_token(conn) == "my_token"
    end

    test "returns nil when no cookie" do
      conn = build_conn(:get, "/")
      assert ApiCsrf.get_csrf_token(conn) == nil
    end
  end

  describe "init/1" do
    test "passes options through" do
      opts = [some: :option]
      assert ApiCsrf.init(opts) == opts
    end
  end
end
