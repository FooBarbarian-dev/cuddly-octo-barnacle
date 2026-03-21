defmodule Clio.Encrypted.Binary do
  @moduledoc "Encrypted binary field type using Cloak."
  use Cloak.Ecto.Binary, vault: Clio.Vault
end
