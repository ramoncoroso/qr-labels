defmodule QrLabelSystem.Designs.Versioning do
  @moduledoc """
  Handles design version history: snapshots, diffs, and restoration.

  Snapshots are created only on explicit user saves (not autosaves).
  Deduplication via MD5 hash prevents storing identical consecutive versions.
  Maximum 50 versions per design.
  """

  import Ecto.Query, warn: false
  require Logger

  alias QrLabelSystem.Repo
  alias QrLabelSystem.Audit
  alias QrLabelSystem.Designs.Design
  alias QrLabelSystem.Designs.DesignVersion

  @max_versions 50

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Creates a snapshot of the current design state.

  Deduplicates by comparing MD5 hash of elements JSON — if nothing changed,
  no new version is created. Triggers async cleanup if over max versions.

  Returns `{:ok, version}` or `{:duplicate, :no_changes}` or `{:error, changeset}`.
  """
  def create_snapshot(%Design{} = design, user_id, opts \\ []) do
    elements_json = serialize_elements(design.elements)
    groups_json = serialize_groups(design.groups)
    hash = compute_hash(design, elements_json, groups_json, opts)

    # Check for duplicate (same hash as most recent version)
    if duplicate_hash?(design.id, hash) do
      {:duplicate, :no_changes}
    else
      next_number = next_version_number(design.id)

      attrs = %{
        design_id: design.id,
        version_number: next_number,
        user_id: user_id,
        name: design.name,
        description: design.description,
        width_mm: design.width_mm,
        height_mm: design.height_mm,
        background_color: design.background_color,
        border_width: design.border_width,
        border_color: design.border_color,
        border_radius: design.border_radius,
        label_type: design.label_type,
        elements: elements_json,
        groups: groups_json,
        element_count: length(design.elements || []),
        snapshot_hash: hash,
        change_message: Keyword.get(opts, :change_message)
      }

      case %DesignVersion{} |> DesignVersion.changeset(attrs) |> Repo.insert() do
        {:ok, version} ->
          # Async cleanup of old versions
          cleanup_async(design.id)

          Audit.log_async("create_version", "design", design.id,
            user_id: user_id,
            metadata: %{version_number: version.version_number})

          {:ok, version}

        {:error, changeset} ->
          Logger.error("Failed to create version snapshot: #{inspect(changeset.errors)}")
          {:error, changeset}
      end
    end
  end

  @doc """
  Returns the latest version number for a design (0 if none exist).
  """
  def latest_version_number(design_id) do
    from(v in DesignVersion, where: v.design_id == ^design_id, select: max(v.version_number))
    |> Repo.one()
    |> Kernel.||(0)
  end

  @doc """
  Lists versions for a design, most recent first.
  Preloads user association for display.
  """
  def list_versions(design_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @max_versions)

    from(v in DesignVersion,
      where: v.design_id == ^design_id,
      order_by: [desc: v.version_number],
      preload: [:user],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Lists versions without loading elements (lighter for panel display).
  Elements are stripped in memory after loading since Ecto can't exclude
  embedded JSONB sub-fields in a SELECT.
  """
  def list_versions_light(design_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @max_versions)

    from(v in DesignVersion,
      where: v.design_id == ^design_id,
      order_by: [desc: v.version_number],
      preload: [:user],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.map(fn v -> %{v | elements: []} end)
  end

  @doc """
  Gets a specific version by design_id and version_number.
  """
  def get_version(design_id, version_number) do
    Repo.one(
      from(v in DesignVersion,
        where: v.design_id == ^design_id and v.version_number == ^version_number,
        preload: [:user]
      )
    )
  end

  @doc """
  Restores a design to a previous version.

  Updates the design to match the version's state without creating a new version.
  A version will be created on the next explicit save.

  Returns `{:ok, updated_design}` or `{:error, reason}`.
  """
  def restore_version(%Design{} = design, version_number, user_id) do
    case get_version(design.id, version_number) do
      nil ->
        {:error, :version_not_found}

      version ->
        restore_attrs = %{
          name: version.name,
          description: version.description,
          width_mm: version.width_mm,
          height_mm: version.height_mm,
          background_color: version.background_color,
          border_width: version.border_width,
          border_color: version.border_color,
          border_radius: version.border_radius,
          label_type: version.label_type,
          elements: version.elements,
          groups: version.groups || []
        }

        case design |> Design.changeset(restore_attrs) |> Repo.update() do
          {:ok, updated_design} ->
            QrLabelSystem.Cache.delete(:designs, {:design, design.id})

            Audit.log_async("restore_version", "design", design.id,
              user_id: user_id,
              metadata: %{restored_from: version_number})

            {:ok, updated_design}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Renames a version by setting its custom_name.
  Pass nil or empty string to clear the custom name.
  """
  def rename_version(design_id, version_number, custom_name) do
    case get_version(design_id, version_number) do
      nil ->
        {:error, :version_not_found}

      version ->
        name = if custom_name == "", do: nil, else: custom_name

        version
        |> DesignVersion.rename_changeset(%{custom_name: name})
        |> Repo.update()
    end
  end

  @doc """
  Generates a human-readable change summary by diffing the current design
  state against the latest version.

  Options:
  - `:restored_from` — version number to prepend "Restaurado desde vN." prefix
  """
  def generate_change_summary(%Design{} = design, opts \\ []) do
    case get_latest_version(design.id) do
      nil ->
        "Version inicial"

      latest_version ->
        parts = []

        # Restore prefix
        parts = case Keyword.get(opts, :restored_from) do
          nil -> parts
          v -> ["Restaurado desde v#{v}" | parts]
        end

        # Field changes
        field_changes = diff_fields_against_design(latest_version, design)
        parts = if map_size(field_changes) > 0 do
          labels = field_changes |> Map.keys() |> Enum.map(&field_label/1) |> Enum.join(", ")
          parts ++ ["Cambiados: #{labels}"]
        else
          parts
        end

        # Element changes — normalize keys via JSON round-trip to match DB format
        current_elements = design.elements |> serialize_elements() |> Jason.encode!() |> Jason.decode!()
        elem_diff = diff_elements(latest_version.elements || [], current_elements)

        elem_parts = []
        elem_parts = if length(elem_diff.added) > 0, do: elem_parts ++ ["+#{length(elem_diff.added)} elementos"], else: elem_parts
        elem_parts = if length(elem_diff.removed) > 0, do: elem_parts ++ ["-#{length(elem_diff.removed)} elementos"], else: elem_parts
        elem_parts = if length(elem_diff.modified) > 0, do: elem_parts ++ ["~#{length(elem_diff.modified)} modificado#{if length(elem_diff.modified) > 1, do: "s", else: ""}"], else: elem_parts

        parts = parts ++ elem_parts

        case parts do
          [] -> "Sin cambios"
          _ -> Enum.join(parts, ". ")
        end
    end
  end

  @doc """
  Computes a diff between a version and its predecessor.
  Returns `{:ok, diff}` or `nil` if it's the first version.
  """
  def diff_against_previous(design_id, version_number) do
    previous = Repo.one(
      from(v in DesignVersion,
        where: v.design_id == ^design_id and v.version_number < ^version_number,
        order_by: [desc: v.version_number],
        limit: 1,
        select: v.version_number
      )
    )

    case previous do
      nil -> nil
      prev_number -> diff_versions(design_id, prev_number, version_number)
    end
  end

  @doc """
  Computes a diff between two versions of a design.

  Returns a map with:
  - `:fields` — map of changed scalar fields `%{field => %{from: old, to: new}}`
  - `:elements` — `%{added: [...], removed: [...], modified: [...]}`
  """
  def diff_versions(design_id, version_a, version_b) do
    with va when not is_nil(va) <- get_version(design_id, version_a),
         vb when not is_nil(vb) <- get_version(design_id, version_b) do
      {:ok, %{
        fields: diff_fields(va, vb),
        elements: diff_elements(va.elements || [], vb.elements || [])
      }}
    else
      nil -> {:error, :version_not_found}
    end
  end

  @doc """
  Returns the total number of versions for a design.
  """
  def version_count(design_id) do
    from(v in DesignVersion, where: v.design_id == ^design_id)
    |> Repo.aggregate(:count)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp serialize_elements(elements) when is_list(elements) do
    Enum.map(elements, fn
      %{__struct__: _} = el -> Map.from_struct(el) |> Map.drop([:__meta__])
      el when is_map(el) -> el
    end)
  end

  defp serialize_elements(_), do: []

  defp serialize_groups(groups) when is_list(groups) do
    Enum.map(groups, fn
      %{__struct__: _} = g -> Map.from_struct(g) |> Map.drop([:__meta__])
      g when is_map(g) -> g
    end)
  end

  defp serialize_groups(_), do: []

  defp compute_hash(design, elements_json, groups_json, _opts) do
    data = Jason.encode!(%{
      name: design.name,
      width_mm: design.width_mm,
      height_mm: design.height_mm,
      background_color: design.background_color,
      border_width: design.border_width,
      border_color: design.border_color,
      border_radius: design.border_radius,
      elements: elements_json,
      groups: groups_json
    })

    :crypto.hash(:md5, data) |> Base.encode16(case: :lower)
  end

  defp duplicate_hash?(design_id, hash) do
    Repo.exists?(
      from(v in DesignVersion,
        where: v.design_id == ^design_id and v.snapshot_hash == ^hash,
        order_by: [desc: v.version_number],
        limit: 1
      )
    )
  end

  defp next_version_number(design_id) do
    case Repo.one(
      from(v in DesignVersion,
        where: v.design_id == ^design_id,
        select: max(v.version_number)
      )
    ) do
      nil -> 1
      max -> max + 1
    end
  end

  defp cleanup_async(design_id) do
    if Application.get_env(:qr_label_system, :env) == :test do
      cleanup_old_versions(design_id)
    else
      Task.Supervisor.start_child(QrLabelSystem.TaskSupervisor, fn ->
        try do
          cleanup_old_versions(design_id)
        catch
          :exit, _ -> :ok
        end
      end)
    end
  end

  defp cleanup_old_versions(design_id) do
    count = version_count(design_id)

    if count > @max_versions do
      cutoff =
        Repo.one(
          from(v in DesignVersion,
            where: v.design_id == ^design_id,
            order_by: [desc: v.version_number],
            offset: ^@max_versions,
            limit: 1,
            select: v.version_number
          )
        )

      if cutoff do
        from(v in DesignVersion,
          where: v.design_id == ^design_id and v.version_number <= ^cutoff
        )
        |> Repo.delete_all()
      end
    end
  end

  # Field diff: compare scalar design fields between two versions
  @diff_fields ~w(name description width_mm height_mm background_color
                   border_width border_color border_radius label_type)a

  defp diff_fields(va, vb) do
    Enum.reduce(@diff_fields, %{}, fn field, acc ->
      old_val = Map.get(va, field)
      new_val = Map.get(vb, field)

      if old_val != new_val do
        Map.put(acc, field, %{from: old_val, to: new_val})
      else
        acc
      end
    end)
  end

  # Element diff: compare by element id (UUID stable)
  defp diff_elements(elements_a, elements_b) do
    ids_a = MapSet.new(elements_a, &element_id/1)
    ids_b = MapSet.new(elements_b, &element_id/1)

    added_ids = MapSet.difference(ids_b, ids_a)
    removed_ids = MapSet.difference(ids_a, ids_b)
    common_ids = MapSet.intersection(ids_a, ids_b)

    map_a = Map.new(elements_a, &{element_id(&1), &1})
    map_b = Map.new(elements_b, &{element_id(&1), &1})

    added = elements_b |> Enum.filter(&(MapSet.member?(added_ids, element_id(&1))))
    removed = elements_a |> Enum.filter(&(MapSet.member?(removed_ids, element_id(&1))))

    modified =
      common_ids
      |> Enum.reduce([], fn id, acc ->
        el_a = map_a[id]
        el_b = map_b[id]

        if el_a != el_b do
          [%{id: id, from: el_a, to: el_b} | acc]
        else
          acc
        end
      end)
      |> Enum.reverse()

    %{added: added, removed: removed, modified: modified}
  end

  defp element_id(element) do
    Map.get(element, "id") || Map.get(element, :id)
  end

  defp get_latest_version(design_id) do
    Repo.one(
      from(v in DesignVersion,
        where: v.design_id == ^design_id,
        order_by: [desc: v.version_number],
        limit: 1
      )
    )
  end

  defp diff_fields_against_design(version, design) do
    Enum.reduce(@diff_fields, %{}, fn field, acc ->
      old_val = Map.get(version, field)
      new_val = Map.get(design, field)

      if old_val != new_val do
        Map.put(acc, field, %{from: old_val, to: new_val})
      else
        acc
      end
    end)
  end

  defp field_label(:name), do: "nombre"
  defp field_label(:description), do: "descripcion"
  defp field_label(:width_mm), do: "ancho"
  defp field_label(:height_mm), do: "alto"
  defp field_label(:background_color), do: "color de fondo"
  defp field_label(:border_width), do: "grosor de borde"
  defp field_label(:border_color), do: "color de borde"
  defp field_label(:border_radius), do: "radio de borde"
  defp field_label(:label_type), do: "tipo de etiqueta"
  defp field_label(field), do: to_string(field)
end
