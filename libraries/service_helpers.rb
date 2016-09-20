module CernerSplunk
  # Mixin Helper methods for the Splunk Service resource
  module ServiceHelpers
    include ResourceHelpers

    # Returns the process id of the daemon or nil if is not running.
    # @return [Integer, nil]
    def service_pid
      install_state = node.run_state['splunk_ingredient']['installations'][install_dir]
      return unless install_state

      pid_file = Pathname.new(install_dir).join('var/run/splunk/splunkd.pid')
      return unless pid_file.exist?

      pid = pid_file.readlines.first.to_i
      pid > 0 ? pid : nil
    end

    # Reports if the daemon for the current package is running
    # @return [Boolean]
    def service_running
      !service_pid.nil?
    end

    # Returns a Pathname of the init.d script for Splunk
    # @return [Pathname] Splunk init.d script location
    def init_script_path
      Pathname.new('/etc/init.d/splunk')
    end

    # Inserts (or updates the existing) ulimit command in the startup script for the current package's service.
    # If the startup script does not exist, it will do nothing.
    def write_initd_ulimit(ulimit)
      limit = ulimit == -1 ? 'unlimited' : ulimit
      file = Chef::Util::FileEdit.new(init_script_path.to_s)
      file.search_file_replace(/^ulimit -n \w*$/, "ulimit -n #{limit}")
      unless file.unwritten_changes?
        file.insert_line_after_match(/^RETVAL=\d$/, "ulimit -n #{limit}")
      end
      raise 'Failed to write ulimit to init.d script' unless file.unwritten_changes?
      file.write_file
    end

    # Alternative to a private method in Chef's ServiceHelpers
    # https://github.com/chef/chef/blob/v12.13.14/lib/chef/platform/service_helpers.rb#L100-L103
    def systemd_is_init?
      proc_path = Pathname.new('/proc/1/comm')
      proc_path.exist? && proc_path.read =~ /systemd/
    end
  end
end
