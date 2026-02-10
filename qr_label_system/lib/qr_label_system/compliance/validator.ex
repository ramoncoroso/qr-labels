defmodule QrLabelSystem.Compliance.Validator do
  @moduledoc """
  Behaviour for compliance validators.
  Each validator checks a design against a specific regulatory standard.
  """

  alias QrLabelSystem.Compliance.Issue
  alias QrLabelSystem.Designs.Design

  @callback validate(Design.t()) :: [Issue.t()]
  @callback standard_name() :: String.t()
  @callback standard_code() :: String.t()
  @callback standard_description() :: String.t()
end
