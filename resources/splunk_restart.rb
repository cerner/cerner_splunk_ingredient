# frozen_string_literal: true
# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_restart
#
# Resource for managing ensured restarts of the Splunk service

class SplunkRestart < Chef::Resource
  include CernerSplunk::RestartHelpers

  resource_name :splunk_restart

  property :name, String, name_property: true, desired_state: false, identity: true
  property :install_dir, String, required: true, desired_state: false
  property :package, [:splunk, :universal_forwarder], required: true

  default_action :check

  def after_created
    package_from_name unless property_is_set?(:package) || property_is_set?(:install_dir)
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
      install_dir default_install_dir
      install_state
    end

    raise 'Attempted to reference resource for Splunk service that does not exist' unless resources(splunk_service: name)
  end

  action_class do
    include CernerSplunk::ProviderHelpers
  end

  action :ensure do
    file marker_path.to_s do
      action :create_if_missing
    end

    notifies :restart, resources(splunk_service: name)
  end

  action :check do
    notifies :restart, resources(splunk_service: name) if marker_path.exist?
  end

  action :clear do
    file marker_path.to_s do
      action :delete
    end
  end
end
