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
  property :install_dir, String, required: true, desired_state: false
  property :user, String, default: lazy { node['current_user'] || package == :splunk ? 'splunk' : 'splunkforwarder' }
  property :group, String, default: lazy { user }
  property :base_url, String, default: 'https://download.splunk.com/products'

  default_action :install

  def after_created
    package_from_name unless property_is_set?(:package) || (@action.include?(:uninstall) && property_is_set?(:install_dir))
  end

  ### Inherited Methods

  def install_state
    load_installation_state && node.run_state['splunk_ingredient']['installations'][install_dir] || {}
  end

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
    @package_path ||= Pathname.new(Chef::Config['file_cache_path']) + CernerSplunk::PathHelpers.filename_from_url(package_url)
  end

  ### Inherited Actions

  load_current_value do |desired|
    raise 'Property install_dir is only available for splunk_install_archive' if resource_name != :splunk_install_archive && property_is_set?(:install_dir)
    if property_is_set? :install_dir
      desired.package = install_state['package'] if @action.first == :uninstall
      package desired.package
    else
      package desired.package
      install_dir desired.install_dir = default_install_dir
    end

    current_value_does_not_exist! if install_state.empty?

    version install_state['version']
    build install_state['build']
  end

  action_class do
    def remove_service
      splunk_service new_resource.name do
        install_dir new_resource.install_dir
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
      execute "chown -R #{user}:#{group} #{install_dir}" unless node['os'] == 'windows' || current_owner == user
    end
  end

  action :install do
    user_resource = Chef::Resource::User.new(user, run_context)
    user_resource.system true
    user_resource.manage_home true
    user_resource.run_action :create

    # The user is created in a group of the same name, so we can skip this step if the group isn't changed.
    if group != user
      group_resource = Chef::Resource::Group.new(group, run_context)
      group_resource.append true
      group_resource.members user
      group_resource.run_action :modify
    end

    raise "Install at #{install_dir} already exists!" unless install_state.empty? || install_state['name'] == name

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
### Platform Specific Resources ###
###################################

class ArchiveInstall < SplunkInstall
  resource_name :splunk_install_archive
  provides :splunk_install, os: %w(linux windows)

  def kernel_string
    case node['os']
    when 'linux' then x64_support ? 'Linux-x86_64.tgz' : 'Linux-i686.tgz'
    when 'windows' then x64_support ? 'windows-64.zip' : 'windows-32.zip'
    end
  end

  action :install do
    super()

    converge_if_changed :version, :build do
      poise_archive package_path do
        destination install_dir
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
  resource_name :splunk_install_redhat
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
  resource_name :splunk_install_debian
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
  resource_name :splunk_install_windows
  provides :splunk_install, platform_family: 'windows'

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
