module CernerSplunk
  # Helper methods for platform oddities in Chef
  module PlatformHelpers
    # Utility method for checking 64-bit compatability
    #
    # @return [Boolean] whether or not the current system supports 64-bit
    def x64_support
      %w(amd64 x86_64).include? node['kernel']['machine']
    end

    # Provides constant defaults for Splunk's package names based on platform and package.
    # Returned hash is nested by package and os. For example, `package_names[:splunk][:linux]` returns
    # the package name for Splunk on Linux.
    #
    # @return [Hash] an index of package names for Splunk and the Universal Forwarder
    def package_names
      {
        splunk: {
          linux: 'splunk',
          windows: 'Splunk Enterprise'
        },
        universal_forwarder: {
          linux: 'splunkforwarder',
          windows: 'UniversalForwarder'
        }
      }
    end
  end
end
