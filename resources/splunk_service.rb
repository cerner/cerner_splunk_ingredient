# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_service
#
# Resource for managing Splunk as a system service
class SplunkService < ChefCompat::Resource
  include CernerSplunk::PlatformHelpers, CernerSplunk::ResourceHelpers,
          CernerSplunk::ServiceHelpers, CernerSplunk::RestartHelpers

  resource_name :splunk_service

  property :name, String, name_property: true, desired_state: false, identity: true
  property :package, [:splunk, :universal_forwarder], required: true
  property :user, [String, nil]
  property :ulimit, Integer

  default_action :start

  def after_created
    package_from_name unless property_is_set? :package
  end

  def service_name
    @service_name ||= service_names[package][node['os'].to_sym]
  end

  def initialize_service
    return unless CernerSplunk::PathHelpers.ftr_pathname(install_dir).exist?

    cmd = "#{command_prefix} enable boot-start#{user ? ' -user ' + user : ''} --accept-license --no-prompt"
    executor = Chef::Resource::Execute.new cmd, run_context
    executor.cwd splunk_bin_path.to_s
    executor.live_stream true if defined? live_stream
    executor.run_action :run
  end

  action_class do
    def service_action(desired_action)
      service service_name do
        provider Chef::Provider::Service::Systemd if systemd_is_init?
        supports start: true, stop: true, restart: true, status: true
        action desired_action
      end
    end
  end

  ### Inherited Actions

  load_current_value do |desired|
    package desired.package

    raise 'Attempted to reference service for Splunk installation that does not exist' unless load_installation_state
    check_restart unless defined?(performed_actions) && !performed_actions.empty?

    unless node['os'] == 'windows'
      if init_script_path.exist?
        limit = init_script_path.read[/ulimit -n (\d+)/, 1].to_i
        ulimit limit if limit > 0
      end
    end

    user current_owner
    desired.user ||= user
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

    converge_if_changed :ulimit do
      write_initd_ulimit ulimit
      ensure_restart if service_running
    end

    service_action :start
  end

  action :restart do
    initialize_service

    converge_if_changed :ulimit do
      write_initd_ulimit ulimit
    end

    service_action :restart
    clear_restart
  end
end
