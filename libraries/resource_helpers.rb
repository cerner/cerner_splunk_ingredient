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
      Pathname.new(install_dir).join('bin')
    end

    def command_prefix
      node['os'] == 'windows' ? 'splunk.exe' : './splunk'
    end

    # Get the owner of the install directory (first creating it, if it doesn't exist)
    def current_owner
      dir = Chef::Resource::Directory.new(install_dir, run_context)
      dir.run_action(:create)
      dir.owner
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
      return false unless Pathname.new(install_dir).join('bin').exist?

      install_state = { 'name' => name, 'x64' => x64_support }
      install_state['package'] = if Pathname.new(install_dir).join('etc/apps/SplunkUniversalForwarder').exist?
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
