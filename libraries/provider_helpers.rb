module CernerSplunk
  # Mixin Helper methods for Splunk Ingredient resources' providers
  module ProviderHelpers
    def changed?(*properties)
      @changed ||= converge_if_changed(*properties) do
      end
    end
  end
end
