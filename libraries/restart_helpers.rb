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
      marker_path.open('w', &:close) unless marker_path.exist?
      notifies :restart, resources(splunk_service: name)
    end

    def check_restart
      notifies :restart, resources(splunk_service: name) if marker_path.exist?
    end

    def clear_restart
      marker_path.delete if marker_path.exist?
    end
  end
end
