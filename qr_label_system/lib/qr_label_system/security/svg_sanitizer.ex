defmodule QrLabelSystem.Security.SvgSanitizer do
  @moduledoc """
  Sanitizes SVG content to prevent XSS attacks.

  SVG files can contain embedded JavaScript and event handlers
  that execute when the image is displayed. This module strips
  all potentially dangerous elements and attributes.

  ## Usage

      case SvgSanitizer.sanitize(svg_content) do
        {:ok, safe_svg} -> # Use the sanitized SVG
        {:error, reason} -> # Handle the error
      end
  """

  @doc """
  Sanitizes an SVG string by removing potentially dangerous content.
  Returns {:ok, sanitized_svg} or {:error, reason}.
  """
  def sanitize(nil), do: {:error, "SVG content is nil"}
  def sanitize(""), do: {:error, "SVG content is empty"}

  def sanitize(svg) when is_binary(svg) do
    svg
    |> remove_dangerous_elements()
    |> remove_dangerous_attributes()
    |> remove_event_handlers()
    |> remove_javascript_urls()
    |> remove_external_references()
    |> validate_result()
  end

  def sanitize(_), do: {:error, "SVG content must be a string"}

  @doc """
  Checks if an SVG is safe without modifying it.
  Returns :ok if safe, {:error, reason} if dangerous content detected.
  """
  def validate(svg) when is_binary(svg) do
    dangerous_patterns = [
      {~r/<script\b/i, "Contains script elements"},
      {~r/\bon\w+\s*=/i, "Contains event handlers"},
      {~r/javascript:/i, "Contains javascript: URLs"},
      {~r/data:\s*text\/html/i, "Contains data:text/html URLs"},
      {~r/<foreignObject\b/i, "Contains foreignObject elements"},
      {~r/<use\s+[^>]*href\s*=\s*["'][^"']*#/i, "Contains potentially dangerous use elements"},
      {~r/xlink:href\s*=\s*["'](?!#)[^"']*/i, "Contains external xlink references"}
    ]

    case Enum.find(dangerous_patterns, fn {pattern, _} -> String.match?(svg, pattern) end) do
      {_, reason} -> {:error, reason}
      nil -> :ok
    end
  end

  def validate(_), do: {:error, "SVG content must be a string"}

  # Private functions

  # Elements that can execute code or embed dangerous content
  @dangerous_elements ~w(
    script
    foreignObject
    iframe
    embed
    object
    applet
    meta
    link
    base
    style
  )

  defp remove_dangerous_elements(svg) do
    Enum.reduce(@dangerous_elements, svg, fn element, acc ->
      # Remove opening and closing tags for each dangerous element
      acc
      |> String.replace(~r/<#{element}\b[^>]*>.*?<\/#{element}>/is, "")
      |> String.replace(~r/<#{element}\b[^>]*\/>/is, "")
      |> String.replace(~r/<#{element}\b[^>]*>/is, "")
    end)
  end

  # Event handlers that can execute JavaScript
  @event_handler_pattern ~r/\s+on\w+\s*=\s*["'][^"']*["']/i

  defp remove_event_handlers(svg) do
    String.replace(svg, @event_handler_pattern, "")
  end

  # Dangerous attributes that can execute code or load external resources
  @dangerous_attributes ~w(
    formaction
    xlink:href
    href
    src
    data
    action
    poster
  )

  defp remove_dangerous_attributes(svg) do
    # Only remove these attributes if they contain dangerous values
    svg
    |> remove_javascript_in_attributes()
    |> remove_data_urls_in_attributes()
  end

  defp remove_javascript_in_attributes(svg) do
    Enum.reduce(@dangerous_attributes, svg, fn attr, acc ->
      pattern = ~r/\s+#{Regex.escape(attr)}\s*=\s*["']javascript:[^"']*["']/i
      String.replace(acc, pattern, "")
    end)
  end

  defp remove_data_urls_in_attributes(svg) do
    # Remove data: URLs that could contain HTML/JavaScript
    pattern = ~r/\s+(href|xlink:href|src)\s*=\s*["']data:text\/html[^"']*["']/i
    String.replace(svg, pattern, "")
  end

  defp remove_javascript_urls(svg) do
    # Remove all javascript: protocol URLs
    String.replace(svg, ~r/javascript:[^"'\s]*/i, "")
  end

  defp remove_external_references(svg) do
    # Keep internal references (starting with #) but remove external ones
    # This prevents loading malicious external content
    svg
    |> String.replace(~r/xlink:href\s*=\s*["'](?!#)https?:\/\/[^"']*["']/i, "")
    |> String.replace(~r/xlink:href\s*=\s*["'](?!#)\/\/[^"']*["']/i, "")
  end

  defp validate_result(svg) do
    case validate(svg) do
      :ok -> {:ok, svg}
      {:error, reason} ->
        # If still dangerous after sanitization, reject completely
        {:error, "Sanitization failed: #{reason}"}
    end
  end
end
