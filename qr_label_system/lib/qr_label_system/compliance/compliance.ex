defmodule QrLabelSystem.Compliance do
  @moduledoc """
  Public facade for regulatory compliance validation.
  Dispatches to the appropriate validator based on the design's compliance_standard.
  """

  alias QrLabelSystem.Compliance.Issue
  alias QrLabelSystem.Designs.Design

  @validators %{
    "gs1" => QrLabelSystem.Compliance.Gs1Validator,
    "eu1169" => QrLabelSystem.Compliance.Eu1169Validator,
    "fmd" => QrLabelSystem.Compliance.FmdValidator
  }

  @doc """
  Validates a design against its configured compliance standard.
  Returns `{standard_name, issues}` or `{nil, []}` if no standard is set.
  """
  def validate(%Design{compliance_standard: nil}), do: {nil, []}
  def validate(%Design{compliance_standard: ""}), do: {nil, []}

  def validate(%Design{compliance_standard: standard} = design) do
    case Map.get(@validators, standard) do
      nil -> {nil, []}
      validator -> {validator.standard_name(), validator.validate(design)}
    end
  end

  @doc """
  Returns available compliance standards as a list of `{code, name, description}`.
  """
  def available_standards do
    Enum.map(@validators, fn {code, mod} ->
      {code, mod.standard_name(), mod.standard_description()}
    end)
    |> Enum.sort_by(&elem(&1, 1))
  end

  @doc """
  Returns true if any issues have :error severity.
  """
  def has_errors?(issues) do
    Enum.any?(issues, &(&1.severity == :error))
  end

  @doc """
  Counts issues grouped by severity.
  """
  def count_by_severity(issues) do
    %{
      errors: Enum.count(issues, &(&1.severity == :error)),
      warnings: Enum.count(issues, &(&1.severity == :warning)),
      infos: Enum.count(issues, &(&1.severity == :info))
    }
  end

  @doc """
  Sorts issues by severity: errors first, then warnings, then infos.
  """
  def sort_issues(issues) do
    order = %{error: 0, warning: 1, info: 2}
    Enum.sort_by(issues, &Map.get(order, &1.severity, 3))
  end

  @doc """
  Serializes issues list to a JSON-friendly format.
  """
  def issues_to_map(issues) do
    Enum.map(issues, fn %Issue{} = issue ->
      %{
        severity: to_string(issue.severity),
        code: issue.code,
        message: issue.message,
        element_id: issue.element_id,
        fix_hint: issue.fix_hint
      }
    end)
  end
end
