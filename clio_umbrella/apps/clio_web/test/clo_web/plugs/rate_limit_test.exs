defmodule CloWeb.Plugs.RateLimitTest do
  use CloWeb.ConnCase, async: false

  alias CloWeb.Plugs.RateLimit

  describe "init/1" do
    test "passes through options" do
      opts = [limit: 10, period: 5000]
      assert RateLimit.init(opts) == opts
    end
  end

  # Note: Full rate limit tests require Hammer to be started.
  # These tests verify the plug's structure and behavior contract.
end
