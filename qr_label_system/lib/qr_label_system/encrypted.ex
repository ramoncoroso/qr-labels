defmodule QrLabelSystem.Encrypted.Map do
  @moduledoc """
  Cloak-encrypted map field type.
  Used for storing sensitive data like database connection credentials.
  """
  use Cloak.Ecto.Map, vault: QrLabelSystem.Vault
end

defmodule QrLabelSystem.Encrypted.Binary do
  @moduledoc """
  Cloak-encrypted binary field type.
  """
  use Cloak.Ecto.Binary, vault: QrLabelSystem.Vault
end
