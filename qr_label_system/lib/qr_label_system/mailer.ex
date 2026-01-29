defmodule QrLabelSystem.Mailer do
  @moduledoc """
  Mailer module for sending emails using Swoosh.
  """
  use Swoosh.Mailer, otp_app: :qr_label_system
end
