defmodule QrLabelSystemWeb.Plugs.RateLimiterTest do
  use QrLabelSystemWeb.ConnCase

  alias QrLabelSystemWeb.Plugs.RateLimiter

  setup do
    # Clear any cached trusted proxies before each test
    # Use try/rescue to handle case where key doesn't exist
    try do
      :persistent_term.erase({RateLimiter, :trusted_proxies})
    rescue
      ArgumentError -> :ok
    catch
      :error, :badarg -> :ok
    end

    :ok
  end

  describe "get_client_ip/1" do
    test "uses remote_ip when no trusted proxies configured", %{conn: conn} do
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
      conn = Map.put(conn, :remote_ip, {0, 0, 0, 0, 0, 0, 0, 1})

      ip = RateLimiter.get_client_ip(conn)

      assert ip == "::1"
    end

    test "handles standard IPv4 remote_ip", %{conn: conn} do
      conn = Map.put(conn, :remote_ip, {127, 0, 0, 1})

      ip = RateLimiter.get_client_ip(conn)

      assert ip == "127.0.0.1"
    end

    test "validates IP format from X-Forwarded-For", %{conn: conn} do
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
    test "allows requests within limit", %{conn: conn} do
      # Use unique IP to avoid test interference
      unique_octet = System.unique_integer([:positive]) |> rem(255)
      conn = Map.put(conn, :remote_ip, {192, 168, 100, unique_octet})

      # First request should be allowed
      result_conn = RateLimiter.rate_limit_login(conn, [])

      refute result_conn.halted
    end

    test "returns 429 with retry-after header when rate limited", %{conn: conn} do
      # Use a unique IP to avoid interference from other tests
      unique_octet = System.unique_integer([:positive]) |> rem(255)
      unique_ip = {192, 168, unique_octet, 1}
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

      # Verify response body contains error message
      response = Jason.decode!(result_conn.resp_body)
      assert response["error"] =~ "Demasiados intentos"
      assert response["retry_after"] == 60
    end
  end

  describe "rate_limit_api/2" do
    test "allows requests within limit", %{conn: conn} do
      unique_octet = System.unique_integer([:positive]) |> rem(255)
      conn = Map.put(conn, :remote_ip, {192, 168, 200, unique_octet})

      result_conn = RateLimiter.rate_limit_api(conn, [])

      refute result_conn.halted
    end

    test "uses user_id for rate limiting when authenticated", %{conn: conn} do
      # When user is authenticated, rate limit should be per-user, not per-IP
      unique_id = System.unique_integer([:positive])
      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 200, 2})
        |> Plug.Conn.assign(:current_user, %{id: unique_id})

      result_conn = RateLimiter.rate_limit_api(conn, [])

      refute result_conn.halted
    end

    test "different users have separate rate limits", %{conn: conn} do
      user1_id = System.unique_integer([:positive])
      user2_id = System.unique_integer([:positive])

      conn1 =
        conn
        |> Map.put(:remote_ip, {192, 168, 200, 3})
        |> Plug.Conn.assign(:current_user, %{id: user1_id})

      conn2 =
        conn
        |> Map.put(:remote_ip, {192, 168, 200, 3})
        |> Plug.Conn.assign(:current_user, %{id: user2_id})

      # Both users should be allowed (separate rate limits)
      result1 = RateLimiter.rate_limit_api(conn1, [])
      result2 = RateLimiter.rate_limit_api(conn2, [])

      refute result1.halted
      refute result2.halted
    end
  end

  describe "rate_limit_uploads/2" do
    test "allows uploads within limit", %{conn: conn} do
      unique_id = System.unique_integer([:positive])
      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 201, 1})
        |> Plug.Conn.assign(:current_user, %{id: unique_id})

      result_conn = RateLimiter.rate_limit_uploads(conn, [])

      refute result_conn.halted
    end

    test "returns 429 when upload limit exceeded", %{conn: conn} do
      unique_id = System.unique_integer([:positive])
      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 201, 2})
        |> Plug.Conn.assign(:current_user, %{id: unique_id})

      # Exhaust upload limit (10 attempts)
      Enum.each(1..10, fn _ ->
        RateLimiter.rate_limit_uploads(conn, [])
      end)

      # 11th attempt should be rate limited
      result_conn = RateLimiter.rate_limit_uploads(conn, [])

      assert result_conn.status == 429
      assert result_conn.halted
    end
  end

  describe "rate_limit_batch_generation/2" do
    test "allows batch generation within limit", %{conn: conn} do
      unique_id = System.unique_integer([:positive])
      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 202, 1})
        |> Plug.Conn.assign(:current_user, %{id: unique_id})

      result_conn = RateLimiter.rate_limit_batch_generation(conn, [])

      refute result_conn.halted
    end

    test "returns 429 when batch generation limit exceeded", %{conn: conn} do
      unique_id = System.unique_integer([:positive])
      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 202, 2})
        |> Plug.Conn.assign(:current_user, %{id: unique_id})

      # Exhaust batch generation limit (5 attempts)
      Enum.each(1..5, fn _ ->
        RateLimiter.rate_limit_batch_generation(conn, [])
      end)

      # 6th attempt should be rate limited
      result_conn = RateLimiter.rate_limit_batch_generation(conn, [])

      assert result_conn.status == 429
      assert result_conn.halted
    end
  end
end
