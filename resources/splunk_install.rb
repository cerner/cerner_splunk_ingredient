# frozen_string_literal: true

# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_install
#
# Resource for managing the installation of Splunk

class SplunkInstall < Chef::Resource
  include CernerSplunk::PlatformHelpers
  include CernerSplunk::PathHelpers
  include CernerSplunk::ResourceHelpers

  resource_name :splunk_install

  property :name, String, name_property: true, identity: true
  property :package, %i[splunk universal_forwarder], required: true
  property :version, String, required: true
  property :build, String, required: true
  property :install_dir, String, required: true, desired_state: false
  property :user, String, default: lazy { default_users[package][node['os'].to_sym] }
  property :group, String, default: lazy { current_group || user }
  property :base_url, String, default: 'https://download.splunk.com/products'

  default_action :install

  def after_created
    package_from_name unless property_is_set?(:package) || (@action.include?(:uninstall) && property_is_set?(:install_dir))
    return unless platform_family? 'windows'
    reset_property :user
    group "#{::ENV['COMPUTERNAME']}\\None"
  end

  ### Inherited Methods

  def install_state
    load_installation_state && node.run_state['splunk_ingredient']['installations'][install_dir] || {}
  end

  # Must be overridden by platform sub-resources
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
    include CernerSplunk::ProviderHelpers

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
      return unless changed? :version, :build

      ruby_block 'load_version_state' do
        block { load_version_state }
      end

      ruby_block "Give ownership of #{install_dir} to #{user}:#{group}" do
        block { CernerSplunk::FileHelpers.deep_change_ownership(install_dir, user, group) }
      end unless platform_family? 'windows'
    end
  end

  action :install do
    raise "Install at #{install_dir} already exists!" unless install_state.empty? || install_state['name'] == name

    return unless changed? :version, :build

    unless platform_family? 'windows'
      declare_resource(:user, user) do
        system true
        manage_home true
        action :create
      end

      declare_resource(:group, group) do
        append true
        members user
        action :create
        # The user is created in a group of the same name, so we can skip this step if the group isn't changed.
        only_if { group != user }
      end
    end

    remote_file package_path.to_s do
      source package_url
      show_progress true if defined? show_progress # Chef 12.9 feature
      notifies :delete, "remote_file[#{package_path}]", :delayed
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
  provides :splunk_install, os: %w[linux windows]

  def kernel_string
    case node['os']
    when 'linux' then x64_support ? 'Linux-x86_64.tgz' : 'Linux-i686.tgz'
    when 'windows' then x64_support ? 'windows-64.zip' : 'windows-32.zip'
    end
  end

  action :install do
    super()

    poise_archive package_path do
      destination install_dir
    end if changed? :version, :build

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

    rpm_package package_name do
      source package_path.to_s
      action :install
    end if changed? :version, :build

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

    dpkg_package package_name do
      source package_path.to_s
      action :install
    end if changed? :version, :build

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

    windows_package package_name do
      source package_path.to_s
      action :install
      options "LAUNCHSPLUNK=0 INSTALL_SHORTCUT=0 AGREETOLICENSE=Yes INSTALLDIR=\"#{install_dir}\""
    end if changed? :version, :build

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
