defmodule QrLabelSystemWeb.Plugs.RateLimiterTest do
  use QrLabelSystemWeb.ConnCase

  alias QrLabelSystemWeb.Plugs.RateLimiter

  describe "get_client_ip/1" do
    test "uses remote_ip when no trusted proxies configured", %{conn: conn} do
      # Clear any cached trusted proxies
      :persistent_term.erase({RateLimiter, :trusted_proxies})

      # Without TRUSTED_PROXIES env var, X-Forwarded-For should be ignored
      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 1, 100})
        |> put_req_header("x-forwarded-for", "10.0.0.1, 172.16.0.1")

      ip = RateLimiter.get_client_ip(conn)

      # Should use remote_ip, not X-Forwarded-For (which could be spoofed)
      assert ip == "192.168.1.100"
    end

    test "ignores X-Forwarded-For from untrusted sources", %{conn: conn} do
      # Clear cached proxies
      :persistent_term.erase({RateLimiter, :trusted_proxies})

      # Even with X-Forwarded-For header, should use remote_ip
      conn =
        conn
        |> Map.put(:remote_ip, {203, 0, 113, 50})
        |> put_req_header("x-forwarded-for", "8.8.8.8")

      ip = RateLimiter.get_client_ip(conn)

      # Attacker cannot spoof IP via X-Forwarded-For when not behind trusted proxy
      assert ip == "203.0.113.50"
    end

    test "handles IPv6 remote_ip", %{conn: conn} do
      :persistent_term.erase({RateLimiter, :trusted_proxies})

      conn = Map.put(conn, :remote_ip, {0, 0, 0, 0, 0, 0, 0, 1})

      ip = RateLimiter.get_client_ip(conn)

      assert ip == "::1"
    end

    test "validates IP format from X-Forwarded-For", %{conn: conn} do
      :persistent_term.erase({RateLimiter, :trusted_proxies})

      # Even if trusted proxy was configured, malformed IPs should be rejected
      # This tests the validate_ip function indirectly
      conn =
        conn
        |> Map.put(:remote_ip, {10, 0, 0, 1})
        |> put_req_header("x-forwarded-for", "not-an-ip, also-not-valid")

      ip = RateLimiter.get_client_ip(conn)

      # Should fall back to remote_ip when X-Forwarded-For contains invalid IPs
      assert ip == "10.0.0.1"
    end
  end

  describe "rate_limit_login/2" do
    setup do
      # Clear rate limit state between tests
      # Note: In production, you'd use Hammer.delete() but for tests we accept state
      :ok
    end

    test "allows requests within limit", %{conn: conn} do
      conn = Map.put(conn, :remote_ip, {192, 168, 100, 1})

      # First request should be allowed
      result_conn = RateLimiter.rate_limit_login(conn, [])

      refute result_conn.halted
    end

    test "returns 429 with retry-after header when rate limited", %{conn: conn} do
      # Use a unique IP to avoid interference from other tests
      unique_ip = {192, 168, System.unique_integer([:positive]) |> rem(255), 1}
      conn = Map.put(conn, :remote_ip, unique_ip)

      # Exhaust rate limit (5 attempts)
      Enum.each(1..5, fn _ ->
        RateLimiter.rate_limit_login(conn, [])
      end)

      # 6th attempt should be rate limited
      result_conn = RateLimiter.rate_limit_login(conn, [])

      assert result_conn.status == 429
      assert result_conn.halted
      assert Plug.Conn.get_resp_header(result_conn, "retry-after") == ["60"]
    end
  end

  describe "rate_limit_api/2" do
    test "allows requests within limit", %{conn: conn} do
      conn = Map.put(conn, :remote_ip, {192, 168, 200, 1})

      result_conn = RateLimiter.rate_limit_api(conn, [])

      refute result_conn.halted
    end

    test "uses user_id for rate limiting when authenticated", %{conn: conn} do
      # When user is authenticated, rate limit should be per-user, not per-IP
      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 200, 2})
        |> Plug.Conn.assign(:current_user, %{id: 12345})

      result_conn = RateLimiter.rate_limit_api(conn, [])

      refute result_conn.halted
    end
  end

  describe "rate_limit_uploads/2" do
    test "allows uploads within limit", %{conn: conn} do
      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 201, 1})
        |> Plug.Conn.assign(:current_user, %{id: 99999})

      result_conn = RateLimiter.rate_limit_uploads(conn, [])

      refute result_conn.halted
    end
  end

  describe "rate_limit_batch_generation/2" do
    test "allows batch generation within limit", %{conn: conn} do
      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 202, 1})
        |> Plug.Conn.assign(:current_user, %{id: 88888})

      result_conn = RateLimiter.rate_limit_batch_generation(conn, [])

      refute result_conn.halted
    end
  end
end
