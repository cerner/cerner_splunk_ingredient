# frozen_string_literal: true

# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_service
#
# Resource for managing Splunk as a system service

class SplunkService < Chef::Resource
  include CernerSplunk::PlatformHelpers
  include CernerSplunk::ResourceHelpers
  include CernerSplunk::ServiceHelpers
  include CernerSplunk::RestartHelpers

  resource_name :splunk_service

  property :name, String, name_property: true, desired_state: false, identity: true
  property :install_dir, String, required: true, desired_state: false
  property :package, %i(splunk universal_forwarder), required: true
  property :ulimit, Integer

  default_action :start

  def after_created
    package_from_name unless property_is_set?(:package) || property_is_set?(:install_dir)
  end

  def service_name
    @service_name ||= service_names[package][node['os'].to_sym]
  end

  def install_state
    unless @install_exists
      raise 'Attempted to reference service for Splunk installation that does not exist' unless load_installation_state
      @install_exists = true
    end

    node.run_state['splunk_ingredient']['installations'][install_dir]
  end

  ### Inherited Actions

  load_current_value do |desired|
    if property_is_set? :install_dir
      install_dir desired.install_dir
      package desired.package = install_state['package']
    else
      package desired.package
      install_dir desired.install_dir = default_install_dir
      install_state
    end

    check_restart unless defined?(performed_actions) && !performed_actions.empty?

    unless node['os'] == 'windows'
      if init_script_path.exist?
        limit = init_script_path.read[/ulimit -n (\d+)/, 1].to_i
        ulimit limit if limit > 0
      end
    end
  end

  action_class do
    include CernerSplunk::ProviderHelpers

    def service_action(desired_action)
      service service_name do
        provider Chef::Provider::Service::Systemd if systemd_is_init?
        supports start: true, stop: true, restart: true, status: true
        action desired_action
      end
    end

    def initialize_service
      return unless CernerSplunk::PathHelpers.ftr_pathname(install_dir).exist?

      cmd = "#{command_prefix} enable boot-start#{platform_family?('windows') ? '' : " -user #{current_owner}"} --accept-license --no-prompt"
      execute cmd do
        cwd splunk_bin_path.to_s
        live_stream true if defined? live_stream
      end
    end
  end

  action :start do
    initialize_service
    service_action :start
  end

  action :stop do
    service_action :stop unless CernerSplunk::PathHelpers.ftr_pathname(install_dir).exist?
  end

  action :restart do
    initialize_service
    service_action :restart
    clear_restart
  end

  action :init do
    initialize_service
  end
end

###################################
### Platform Specific Providers ###
###################################

class LinuxService < SplunkService
  resource_name :splunk_service
  provides :splunk_service, os: 'linux'

  action :start do
    initialize_service

    if changed? :ulimit
      write_initd_ulimit ulimit
      ensure_restart if service_running
    end

    service_action :start
  end

  action :restart do
    initialize_service

    write_initd_ulimit ulimit if changed? :ulimit

    service_action :restart
    clear_restart
  end
end
