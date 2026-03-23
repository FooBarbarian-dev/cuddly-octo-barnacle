defmodule CloWeb.Gettext do
  @moduledoc "Gettext module for CloWeb. Required by Backpex for i18n support."
  use Gettext.Backend, otp_app: :clio_web
end
