defmodule QrLabelSystem.Compliance.Issue do
  @moduledoc """
  Represents a compliance validation issue found in a design.
  """

  @type severity :: :error | :warning | :info

  @type t :: %__MODULE__{
          severity: severity(),
          code: String.t(),
          message: String.t(),
          element_id: String.t() | nil,
          fix_hint: String.t() | nil,
          fix_action: map() | nil
        }

  @enforce_keys [:severity, :code, :message]
  defstruct [:severity, :code, :message, :element_id, :fix_hint, :fix_action]

  def error(code, message, opts \\ []) do
    %__MODULE__{
      severity: :error,
      code: code,
      message: message,
      element_id: Keyword.get(opts, :element_id),
      fix_hint: Keyword.get(opts, :fix_hint),
      fix_action: Keyword.get(opts, :fix_action)
    }
  end

  def warning(code, message, opts \\ []) do
    %__MODULE__{
      severity: :warning,
      code: code,
      message: message,
      element_id: Keyword.get(opts, :element_id),
      fix_hint: Keyword.get(opts, :fix_hint),
      fix_action: Keyword.get(opts, :fix_action)
    }
  end

  def info(code, message, opts \\ []) do
    %__MODULE__{
      severity: :info,
      code: code,
      message: message,
      element_id: Keyword.get(opts, :element_id),
      fix_hint: Keyword.get(opts, :fix_hint),
      fix_action: Keyword.get(opts, :fix_action)
    }
  end
end
