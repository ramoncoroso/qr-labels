defmodule QrLabelSystem.Vault do
  @moduledoc """
  Vault for encrypting sensitive data like database credentials.
  Uses Cloak for transparent encryption/decryption.
  """
  use Cloak.Vault, otp_app: :qr_label_system
end
