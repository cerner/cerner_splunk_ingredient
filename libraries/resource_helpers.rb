# frozen_string_literal: true

module CernerSplunk
  # Mixin Helper methods for Splunk Ingredient resources
  module ResourceHelpers
    include PlatformHelpers

    # Determines the correct install directory in the context of a Splunk resource.
    # Expects `package` to be in the context of the current resource.
    #
    # @return [String] the install directory for the current Splunk resource
    def default_install_dir
      @install_dir ||= CernerSplunk::PathHelpers.default_install_dirs[package][node['os'].to_sym]
      raise "Unsupported Combination: #{package} + #{node['os']}" unless @install_dir
      @install_dir
    end

    def splunk_bin_path
      Pathname.new(install_dir) + 'bin'
    end

    def command_prefix
      platform_family?('windows') ? 'splunk.exe' : './splunk'
    end

    # Get the owner of the install directory
    def current_owner(options = {})
      if platform_family? 'windows'
        return "#{::ENV['COMPUTERNAME']}\\None" unless Pathname.new(install_dir).exist?

        require 'chef/win32/security'
        security_descriptor = Chef::ReservedNames::Win32::Security.get_named_security_info(install_dir)
        return security_descriptor.owner if options[:sid]
        security_descriptor.owner.account_name
      elsif Pathname.new(install_dir).exist?
        Etc.getpwuid(Pathname.new(install_dir).stat.uid).name
      end
    end

    # Get the group of the install directory
    def current_group(options = {})
      if platform_family? 'windows'
        return "#{::ENV['COMPUTERNAME']}\\None" unless Pathname.new(install_dir).exist?

        require 'chef/win32/security'
        security_descriptor = Chef::ReservedNames::Win32::Security.get_named_security_info(install_dir)
        return security_descriptor.group if options[:sid]
        security_descriptor.group.account_name
      elsif Pathname.new(install_dir).exist?
        Etc.getgrgid(Pathname.new(install_dir).stat.gid).name
      end
    end

    # Sets the package based on the resource name.
    def package_from_name
      case name.downcase
      when 'splunk' then package :splunk
      when 'universal_forwarder' then package :universal_forwarder
      else raise 'Package must be specified (:splunk or :universal_forwarder)'
      end
    end

    def load_installation_state
      node.run_state['splunk_ingredient'] ||= { 'installations' => {} }
      self_state = node.run_state['splunk_ingredient']
      return true if self_state['installations'][install_dir]
      return false unless (Pathname.new(install_dir) + 'bin').exist?

      install_state = { 'name' => name, 'x64' => x64_support, 'path' => install_dir }
      install_state['package'] = if (Pathname.new(install_dir) + 'etc/apps/SplunkUniversalForwarder').exist?
                                   :universal_forwarder
                                 else
                                   :splunk
                                 end

      self_state['current_installation'] = self_state['installations'][install_dir] = install_state
      load_version_state
      true
    end

    def load_version_state
      install_state = node.run_state['splunk_ingredient']['installations'][install_dir]
      if install_state
        version_file = CernerSplunk::PathHelpers.version_pathname(install_dir)
        raise 'Installation seems to exist, but splunk.version not found!' unless version_file.exist?

        version_data = version_file.read
        installed_version, installed_build = version_data.match(/VERSION=(\d(?:\.\d)+).+BUILD=([\w]+)/m).captures
        install_state['version'] = installed_version
        install_state['build'] = installed_build
      else
        load_installation_state
      end
    end
  end
end
