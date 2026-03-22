defmodule Clio.Vault do
  @moduledoc "Cloak encryption vault for AES-GCM field-level encryption of sensitive database columns."
  use Cloak.Vault, otp_app: :clio
end
