# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_install
#
# Resource for managing the installation of Splunk
class SplunkInstall < ChefCompat::Resource
  include CernerSplunk::PlatformHelpers, CernerSplunk::PathHelpers, CernerSplunk::ResourceHelpers

  resource_name :splunk_install

  property :name, String, name_property: true, identity: true
  property :package, [:splunk, :universal_forwarder], required: true
  property :version, String, required: true
  property :build, String, required: true
  property :user, String, default: lazy { node['current_user'] || package == :splunk ? 'splunk' : 'splunkforwarder' }
  property :base_url, String, default: 'https://download.splunk.com/products'

  default_action :install

  def after_created
    package_from_name unless property_is_set? :package
    load_installation_state
  end

  ### Inherited Methods

  # Must be overridden by a platform provider
  def kernel_string
    raise 'No implementation for current platform'
  end

  def package_name
    @package_name ||= package_names[package][node['os'].to_sym]
    raise "Unsupported Combination: #{package} + #{node['os']}" unless @package_name
    @package_name
  end

  def package_url
    @package_url ||=
      case package
      when :splunk then "#{base_url}/splunk/releases/#{version}/#{node['os']}/splunk"
      when :universal_forwarder then "#{base_url}/universalforwarder/releases/#{version}/#{node['os']}/splunkforwarder"
      end + "-#{version}-#{build}-#{kernel_string}"
  end

  def package_path
    @package_path ||= Pathname.new(Chef::Config['file_cache_path']) + filename_from_url(package_url)
  end

  ### Inherited Actions

  load_current_value do |desired|
    package desired.package

    install_state = node.run_state['splunk_ingredient']['installations'][install_dir]
    current_value_does_not_exist! unless install_state
    version install_state['version']
    build install_state['build']
  end

  action_class do
    def remove_service
      splunk_service new_resource.name do
        package new_resource.package
        action :stop
      end

      execute "#{command_prefix} disable boot-start" do
        cwd splunk_bin_path.to_s
        live_stream true if defined? live_stream
      end
    end

    def post_install
      ruby_block 'load_version_state' do
        block { load_version_state }
      end
      execute "chown -R #{user}:#{user} #{install_dir}" unless node['os'] == 'windows' || current_owner == user
    end
  end

  action :install do
    user_resource = Chef::Resource::User.new(user, run_context)
    user_resource.system true
    user_resource.manage_home true
    user_resource.run_action :create

    install_state = node.run_state['splunk_ingredient']['installations'][install_dir]
    raise "Install at #{install_dir} already exists!" if install_state && install_state['name'] != name

    converge_if_changed :version, :build do
      remote_file package_path.to_s do
        source package_url
        show_progress true if defined? show_progress # Chef 12.9 feature
        notifies :delete, "remote_file[#{package_path}]", :delayed
      end
    end
  end

  action :uninstall do
    self_state = node.run_state['splunk_ingredient']
    self_state.delete('current_installation')
    self_state['installations'].delete(install_dir)

    directory install_dir do
      recursive true
      action :delete
    end
  end
end

###################################
### Platform Specific Providers ###
###################################
# rubocop:disable Documentation

class LinuxInstall < SplunkInstall
  resource_name :splunk_install
  provides :splunk_install, os: 'linux'

  def kernel_string
    x64_support ? 'Linux-x86_64.tgz' : 'Linux-i686.tgz'
  end

  action :install do
    super()

    converge_if_changed :version, :build do
      tar_extract package_path do
        action :extract_local
        target_dir install_dir
      end
    end

    post_install
  end

  action :uninstall do
    remove_service
    super()
  end
end

class RedhatInstall < SplunkInstall
  resource_name :splunk_install
  provides :splunk_install, platform_family: 'rhel'

  def kernel_string
    x64_support ? 'linux-2.6-x86_64.rpm' : 'i386.rpm'
  end

  action :install do
    super()

    converge_if_changed :version, :build do
      rpm_package package_name do
        source package_path.to_s
        action :install
      end
    end

    post_install
  end

  action :uninstall do
    remove_service
    rpm_package package_name do
      action :remove
    end

    super()
  end
end

class DebianInstall < SplunkInstall
  resource_name :splunk_install
  provides :splunk_install, platform_family: 'debian'

  def kernel_string
    x64_support ? 'linux-2.6-amd64.deb' : 'linux-2.6-intel.deb'
  end

  action :install do
    super()

    converge_if_changed :version, :build do
      dpkg_package package_name do
        source package_path.to_s
        action :install
      end
    end

    post_install
  end

  action :uninstall do
    remove_service
    dpkg_package package_name do
      action :purge
    end

    super()
  end
end

class WindowsInstall < SplunkInstall
  resource_name :splunk_install
  provides :splunk_install, os: 'windows'

  def kernel_string
    x64_support ? 'x64-release.msi' : 'x86-release.msi'
  end

  action :install do
    super()

    converge_if_changed :version, :build do
      windows_package package_name do
        source package_path.to_s
        action :install
        options 'LAUNCHSPLUNK=0 INSTALL_SHORTCUT=0 AGREETOLICENSE=Yes'
      end
    end

    post_install
  end

  action :uninstall do
    remove_service
    windows_package package_name do
      action :remove
    end

    super()
  end
end
