defmodule QrLabelSystem.Pagination do
  @moduledoc """
  Shared pagination utilities for all contexts.

  Provides consistent pagination behavior across the application.
  """

  import Ecto.Query, warn: false

  @default_page 1
  @default_per_page 20
  @max_per_page 100

  @doc """
  Paginates a query based on params.

  ## Options
    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 20, max: 100)

  ## Returns
  A map with:
    * `:entries` - The paginated results
    * `:page` - Current page number
    * `:per_page` - Items per page
    * `:total` - Total number of entries
    * `:total_pages` - Total number of pages
    * `:has_next` - Whether there's a next page
    * `:has_prev` - Whether there's a previous page
  """
  def paginate(query, repo, params \\ %{}) do
    page = parse_page(params)
    per_page = parse_per_page(params)
    offset = (page - 1) * per_page

    # Get total count (excluding preloads for efficiency)
    total =
      query
      |> exclude(:preload)
      |> exclude(:order_by)
      |> exclude(:select)
      |> repo.aggregate(:count)

    # Get paginated entries
    entries =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> repo.all()

    total_pages = calculate_total_pages(total, per_page)

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: total_pages,
      has_next: page < total_pages,
      has_prev: page > 1
    }
  end

  @doc """
  Parses page number from params.
  """
  def parse_page(params) do
    params
    |> get_param(["page", :page], @default_page)
    |> parse_positive_int(@default_page)
  end

  @doc """
  Parses per_page number from params.
  """
  def parse_per_page(params) do
    params
    |> get_param(["per_page", :per_page], @default_per_page)
    |> parse_positive_int(@default_per_page)
    |> min(@max_per_page)
  end

  @doc """
  Parses an integer from various input types.
  Returns default if parsing fails.
  """
  def parse_int(value, default \\ 0)
  def parse_int(value, _default) when is_integer(value), do: value
  def parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
  def parse_int(_, default), do: default

  @doc """
  Parses a positive integer (>= 1).
  """
  def parse_positive_int(value, default) do
    result = parse_int(value, default)
    if result >= 1, do: result, else: default
  end

  # Private functions

  defp get_param(params, keys, default) when is_list(keys) do
    Enum.find_value(keys, default, fn key ->
      case Map.get(params, key) do
        nil -> nil
        "" -> nil
        value -> value
      end
    end)
  end

  defp calculate_total_pages(0, _per_page), do: 1
  defp calculate_total_pages(total, per_page), do: ceil(total / per_page)
end
