defmodule QrLabelSystem.Designs.DesignApproval do
  @moduledoc """
  Schema for design approval history.

  Each record represents an action in the approval workflow:
  - request_review: owner submits design for review
  - approve: admin approves the design
  - reject: admin rejects the design (returns to draft)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @valid_actions ~w(request_review approve reject)

  schema "design_approvals" do
    field :action, :string
    field :comment, :string

    belongs_to :design, QrLabelSystem.Designs.Design
    belongs_to :user, QrLabelSystem.Accounts.User

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def changeset(approval, attrs) do
    approval
    |> cast(attrs, [:design_id, :user_id, :action, :comment])
    |> validate_required([:design_id, :user_id, :action])
    |> validate_inclusion(:action, @valid_actions)
    |> validate_length(:comment, max: 1000)
    |> foreign_key_constraint(:design_id)
    |> foreign_key_constraint(:user_id)
  end
end
