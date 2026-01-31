defmodule QrLabelSystemWeb.Plugs.LocaleTest do
  use QrLabelSystemWeb.ConnCase

  alias QrLabelSystemWeb.Plugs.Locale

  describe "call/2 - locale detection" do
    test "uses locale from query parameter" do
      conn =
        build_conn(:get, "/?locale=en")
        |> init_test_session(%{})
        |> fetch_query_params()

      conn = Locale.call(conn, [])

      assert conn.assigns.locale == "en"
      assert Gettext.get_locale(QrLabelSystemWeb.Gettext) == "en"
    end

    test "uses locale from session" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{user_locale: "en"})

      conn = Locale.call(conn, [])

      assert conn.assigns.locale == "en"
    end

    test "uses locale from Accept-Language header" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})
        |> put_req_header("accept-language", "en-US,en;q=0.9")

      conn = Locale.call(conn, [])

      assert conn.assigns.locale == "en"
    end

    test "falls back to default locale" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})

      conn = Locale.call(conn, [])

      assert conn.assigns.locale == "es"
    end

    test "query parameter takes precedence over session" do
      conn =
        build_conn(:get, "/?locale=en")
        |> init_test_session(%{user_locale: "es"})
        |> fetch_query_params()

      conn = Locale.call(conn, [])

      assert conn.assigns.locale == "en"
    end

    test "session takes precedence over Accept-Language" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{user_locale: "es"})
        |> put_req_header("accept-language", "en-US")

      conn = Locale.call(conn, [])

      assert conn.assigns.locale == "es"
    end

    test "rejects unsupported locale from query parameter" do
      conn =
        build_conn(:get, "/?locale=fr")
        |> init_test_session(%{})
        |> fetch_query_params()

      conn = Locale.call(conn, [])

      assert conn.assigns.locale == "es"  # Falls back to default
    end

    test "stores locale in session" do
      conn =
        build_conn(:get, "/?locale=en")
        |> init_test_session(%{})
        |> fetch_query_params()

      conn = Locale.call(conn, [])

      assert get_session(conn, :user_locale) == "en"
    end
  end

  describe "detect_locale/1 - Accept-Language parsing" do
    test "parses simple language code" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})
        |> put_req_header("accept-language", "es")

      locale = Locale.detect_locale(conn)

      assert locale == "es"
    end

    test "parses language with region" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})
        |> put_req_header("accept-language", "es-MX")

      locale = Locale.detect_locale(conn)

      assert locale == "es"
    end

    test "parses multiple languages with quality" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})
        |> put_req_header("accept-language", "fr;q=0.9,en;q=0.8,es;q=0.7")

      locale = Locale.detect_locale(conn)

      # fr is not supported, en is next highest
      assert locale == "en"
    end

    test "handles missing quality value" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})
        |> put_req_header("accept-language", "en")

      locale = Locale.detect_locale(conn)

      assert locale == "en"
    end

    test "handles complex Accept-Language header" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})
        |> put_req_header("accept-language", "es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7")

      locale = Locale.detect_locale(conn)

      assert locale == "es"
    end
  end

  describe "supported_locales/0" do
    test "returns list of supported locales" do
      locales = Locale.supported_locales()

      assert "en" in locales
      assert "es" in locales
    end
  end

  describe "default_locale/0" do
    test "returns default locale" do
      assert Locale.default_locale() == "es"
    end
  end

  describe "init/1" do
    test "passes options through" do
      opts = [some: :option]
      assert Locale.init(opts) == opts
    end
  end
end
