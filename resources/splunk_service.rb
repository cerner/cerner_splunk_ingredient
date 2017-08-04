# frozen_string_literal: true

# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_service
#
# Resource for managing Splunk as a system service

class SplunkService < Chef::Resource
  include CernerSplunk::PlatformHelpers
  include CernerSplunk::ResourceHelpers
  include CernerSplunk::ServiceHelpers

  resource_name :splunk_service

  property :name, String, name_property: true, desired_state: false, identity: true
  property :install_dir, String, required: true, desired_state: false
  property :package, %i[splunk universal_forwarder], required: true
  property :ulimit, Integer

  default_action :start

  def after_created
    package_from_name unless property_is_set?(:package) || property_is_set?(:install_dir)
    # Check for a restart marker at the end of the Chef run. Only do this if we're in the root run context;
    # if there is a parent run context, we are actually in another resource and the delayed action would run
    # at the end of that resource instead of the end of the Chef run.
    delayed_action :__guarded_restart if run_context.parent_run_context.nil?
  end

  def service_name
    @service_name ||= service_names[package][node['os'].to_sym]
  end

  def marker_path
    @marker_path ||= Pathname.new(install_dir) + 'restart_on_chef_client'
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

    unless node['os'] == 'windows'
      if init_script_path.exist?
        limit = init_script_path.read[/ulimit -n (\d+)/, 1].to_i
        ulimit limit if limit.positive?
      end
    end
  end

  action_class do
    include CernerSplunk::ProviderHelpers

    def service_action(desired_action)
      marker = file(marker_path.to_s) do
        action :nothing
      end
      service service_name do
        provider Chef::Provider::Service::Systemd if systemd_is_init?
        action desired_action
        notifies :delete, marker, :immediately
      end
    end

    def initialize_service
      return unless CernerSplunk::PathHelpers.ftr_pathname(install_dir).exist?

      cmd = "#{command_prefix} enable boot-start#{platform_family?('windows') ? '' : " -user #{current_owner}"} --accept-license --answer-yes --no-prompt"
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
  end

  action :desired_restart do
    file marker_path.to_s do
      action :create_if_missing
    end
  end

  action :__guarded_restart do
    run_context.add_delayed_action(Notification.new(current_resource, :restart, current_resource)) if marker_path.exist?
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
      file marker_path.to_s do
        action :create_if_missing
      end
    end

    service_action :start
  end

  action :restart do
    initialize_service

    write_initd_ulimit ulimit if changed? :ulimit

    service_action :restart
  end
end
