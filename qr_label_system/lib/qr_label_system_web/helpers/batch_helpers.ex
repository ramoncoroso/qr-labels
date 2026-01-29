defmodule QrLabelSystemWeb.Helpers.BatchHelpers do
  @moduledoc """
  Helper functions for batch-related views.

  Provides consistent status colors, labels, and icons across all batch views.
  """

  @doc """
  Returns the CSS classes for a batch status badge.
  """
  def status_badge_class(status) do
    "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color_class(status)}"
  end

  @doc """
  Returns the background and text color classes for a status.
  """
  def status_color_class("draft"), do: "bg-gray-100 text-gray-800"
  def status_color_class("pending"), do: "bg-yellow-100 text-yellow-800"
  def status_color_class("processing"), do: "bg-blue-100 text-blue-800"
  def status_color_class("ready"), do: "bg-green-100 text-green-800"
  def status_color_class("printed"), do: "bg-indigo-100 text-indigo-800"
  def status_color_class("archived"), do: "bg-purple-100 text-purple-800"
  def status_color_class("error"), do: "bg-red-100 text-red-800"
  def status_color_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Returns the human-readable label for a status.
  """
  def status_label("draft"), do: "Borrador"
  def status_label("pending"), do: "Pendiente"
  def status_label("processing"), do: "Procesando"
  def status_label("ready"), do: "Listo"
  def status_label("printed"), do: "Impreso"
  def status_label("archived"), do: "Archivado"
  def status_label("error"), do: "Error"
  def status_label(status), do: String.capitalize(status || "Desconocido")

  @doc """
  Returns an SVG icon for a status.
  """
  def status_icon("draft") do
    """
    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
    </svg>
    """
  end

  def status_icon("pending") do
    """
    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  def status_icon("processing") do
    """
    <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
    </svg>
    """
  end

  def status_icon("ready") do
    """
    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  def status_icon("printed") do
    """
    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
    </svg>
    """
  end

  def status_icon("archived") do
    """
    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4" />
    </svg>
    """
  end

  def status_icon("error") do
    """
    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  def status_icon(_) do
    """
    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  @doc """
  Returns available batch statuses for filtering.
  """
  def available_statuses do
    [
      {"draft", "Borrador"},
      {"pending", "Pendiente"},
      {"processing", "Procesando"},
      {"ready", "Listo"},
      {"printed", "Impreso"},
      {"archived", "Archivado"},
      {"error", "Error"}
    ]
  end

  @doc """
  Formats the number of labels for display.
  """
  def format_label_count(nil), do: "0 etiquetas"
  def format_label_count(0), do: "0 etiquetas"
  def format_label_count(1), do: "1 etiqueta"
  def format_label_count(count) when is_integer(count) do
    formatted = Number.Delimit.number_to_delimited(count, delimiter: ",", precision: 0)
    "#{formatted} etiquetas"
  rescue
    _ -> "#{count} etiquetas"
  end
  def format_label_count(count), do: "#{count} etiquetas"

  @doc """
  Formats a datetime for display.
  """
  def format_datetime(nil), do: "-"
  def format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  end
  def format_datetime(%NaiveDateTime{} = ndt) do
    Calendar.strftime(ndt, "%d/%m/%Y %H:%M")
  end
  def format_datetime(_), do: "-"

  @doc """
  Returns relative time (e.g., "hace 5 minutos").
  """
  def relative_time(nil), do: "-"
  def relative_time(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)

    cond do
      diff < 60 -> "hace unos segundos"
      diff < 3600 -> "hace #{div(diff, 60)} min"
      diff < 86400 -> "hace #{div(diff, 3600)} horas"
      diff < 604800 -> "hace #{div(diff, 86400)} días"
      true -> format_datetime(dt)
    end
  end
  def relative_time(_), do: "-"
end
