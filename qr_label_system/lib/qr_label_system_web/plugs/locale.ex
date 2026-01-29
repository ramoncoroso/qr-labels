defmodule QrLabelSystemWeb.Plugs.Locale do
  @moduledoc """
  Plug for setting the locale based on user preferences.

  Locale detection priority:
  1. Query parameter (?locale=es)
  2. User preference (stored in session)
  3. Accept-Language header
  4. Default locale (configured in config)

  ## Usage

  Add to your router:

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug QrLabelSystemWeb.Plugs.Locale
        # ...
      end

  ## Supported Locales

  Configure in your config:

      config :qr_label_system, QrLabelSystemWeb.Plugs.Locale,
        default_locale: "es",
        supported_locales: ["en", "es"]
  """
  import Plug.Conn
  require Logger

  @default_locale "es"
  @supported_locales ["en", "es"]
  @locale_param "locale"
  @session_key :user_locale

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    locale = detect_locale(conn)
    Gettext.put_locale(QrLabelSystemWeb.Gettext, locale)

    conn
    |> put_session(@session_key, locale)
    |> assign(:locale, locale)
  end

  @doc """
  Detects the locale from various sources.
  """
  def detect_locale(conn) do
    conn = fetch_query_params(conn)

    locale =
      get_locale_from_params(conn) ||
        get_locale_from_session(conn) ||
        get_locale_from_header(conn) ||
        default_locale()

    if locale in supported_locales() do
      locale
    else
      default_locale()
    end
  end

  @doc """
  Returns the list of supported locales.
  """
  def supported_locales do
    Application.get_env(:qr_label_system, __MODULE__, [])
    |> Keyword.get(:supported_locales, @supported_locales)
  end

  @doc """
  Returns the default locale.
  """
  def default_locale do
    Application.get_env(:qr_label_system, __MODULE__, [])
    |> Keyword.get(:default_locale, @default_locale)
  end

  # Private functions

  defp get_locale_from_params(conn) do
    conn.params[@locale_param]
  end

  defp get_locale_from_session(conn) do
    conn = fetch_session(conn)
    get_session(conn, @session_key)
  end

  defp get_locale_from_header(conn) do
    case get_req_header(conn, "accept-language") do
      [accept_language | _] -> parse_accept_language(accept_language)
      [] -> nil
    end
  end

  defp parse_accept_language(header) do
    # Parse Accept-Language header (e.g., "es-ES,es;q=0.9,en;q=0.8")
    header
    |> String.split(",")
    |> Enum.map(&parse_language_tag/1)
    |> Enum.sort_by(fn {_lang, quality} -> -quality end)
    |> Enum.find_value(fn {lang, _quality} ->
      # Try exact match first, then language code only
      cond do
        lang in supported_locales() -> lang
        String.split(lang, "-") |> List.first() |> then(&(&1 in supported_locales())) ->
          String.split(lang, "-") |> List.first()
        true -> nil
      end
    end)
  end

  defp parse_language_tag(tag) do
    case String.split(String.trim(tag), ";") do
      [lang] ->
        {String.downcase(lang), 1.0}

      [lang, quality_str] ->
        quality =
          case Regex.run(~r/q=(\d+\.?\d*)/, quality_str) do
            [_, q] -> String.to_float(q)
            _ -> 1.0
          end

        {String.downcase(String.trim(lang)), quality}

      _ ->
        {"", 0.0}
    end
  end
end
