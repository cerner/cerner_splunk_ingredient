# frozen_string_literal: true

module CernerSplunk
  # Helper methods for file manipulation
  module FileHelpers
    def self.change_ownership(path, desired_owner, desired_group = nil)
      path = Pathname.new(path)
      return if Chef.node.platform_family?('windows')

      require 'fileutils'
      FileUtils.chown(desired_owner, desired_group, path.to_s)
    end

    def self.deep_change_ownership(path, owner, group = nil)
      return if Chef.node.platform_family?('windows')

      change_ownership(path, owner, group)
      Pathname.glob(Pathname.new(path) + '**/*').each { |sub_path| change_ownership(sub_path, owner, group) }
    end
  end unless defined? FileHelpers
end
