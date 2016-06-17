module CernerSplunk
  # Helper methods for Splunk-related file and URL paths
  module PathHelpers
    # Provides constant defaults for Splunk's various default install directories based on platform and package.
    # Returned hash is nested by package and os. For example, `default_install_dirs[:splunk][:linux]` returns
    # the default directory for Splunk on Linux.
    #
    # @return [Hash] an index of default install directories for Splunk and the Universal Forwarder
    def default_install_dirs
      {
        splunk: {
          linux: '/opt/splunk',
          windows: 'c:\Program Files\Splunk'
        },
        universal_forwarder: {
          linux: '/opt/splunkforwarder',
          windows: 'c:\Program Files\SplunkUniversalForwarder'
        }
      }
    end

    # Utility method for splitting the filename from a URL.
    #
    # @param url [String]
    # @return [String] the filename at the end of the URL
    def filename_from_url(url)
      Pathname.new(URI.parse(url).path).basename.to_s
    end

    # Append the relative path of Splunk's version file to the home directory path
    #
    # @param splunk_home [String] the absolute path to Splunk's home directory
    # @return [Pathname] the absolute path to Splunk's version file
    def version_pathname(splunk_home)
      Pathname.new(splunk_home).join('etc/splunk.version')
    end
  end
end
