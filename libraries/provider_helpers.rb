module CernerSplunk
  # Mixin Helper methods for Splunk Ingredient resources' providers
  module ProviderHelpers
    def changed?(*properties)
      converge_if_changed(*properties) do
      end
    end

    def change_ownership(path, desired_owner, desired_group = nil, options = {})
      path = Pathname.new(path)
      return if platform_family?('windows')

      require 'fileutils'
      FileUtils.chown(desired_owner, desired_group, path.to_s)
    end

    def deep_change_ownership(path, owner, group = nil)
      return if platform_family?('windows')

      change_ownership(path, owner, group, access: :full_control, inherit: true)
      Pathname.glob(Pathname.new(path).join('**/*')).each { |sub_path| change_ownership(sub_path, owner, group) }
    end
  end
end
