# frozen_string_literal: true

module CernerSplunk
  # Mixin Helper methods for Splunk Ingredient resources to ensure a service restart
  module RestartHelpers
    include ResourceHelpers
    def marker_path
      @marker_path ||= Pathname.new(install_dir) + 'restart_on_chef_client'
      @marker_path
    end

    # Notifies splunk_service to restart and places a marker file to ensure restart next time if this chef run dies.
    def ensure_restart
      @restart_resource ||= Chef::Resource::CernerSplunkIngredientSplunkRestart::SplunkRestart.new name, run_context
      @restart_resource.install_dir install_dir
      @restart_resource.run_action :ensure
    end

    def check_restart
      @restart_resource ||= Chef::Resource::CernerSplunkIngredientSplunkRestart::SplunkRestart.new name, run_context
      @restart_resource.install_dir install_dir
      @restart_resource.run_action :check
    end

    def clear_restart
      @restart_resource ||= Chef::Resource::CernerSplunkIngredientSplunkRestart::SplunkRestart.new name, run_context
      @restart_resource.install_dir install_dir
      @restart_resource.run_action :clear
    end
  end
end
