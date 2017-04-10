# frozen_string_literal: true

module CernerSplunk
  # Helper methods for platform oddities in Chef
  module PlatformHelpers
    # Utility method for checking 64-bit compatability
    #
    # @return [Boolean] whether or not the current system supports 64-bit
    def x64_support
      %w[amd64 x86_64].include? node['kernel']['machine']
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

    def service_names
      {
        splunk: {
          linux: 'splunk',
          windows: 'splunkd'
        },
        universal_forwarder: {
          linux: 'splunk',
          windows: 'splunkforwarder'
        }
      }
    end

    def default_users
      {
        splunk: {
          windows: node['current_user'],
          linux: 'splunk'
        },
        universal_forwarder: {
          windows: node['current_user'],
          linux: 'splunk'
        }
      }
    end
  end
end
