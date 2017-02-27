# frozen_string_literal: true
module CernerSplunk
  # Class object for parsing and encapsulating Splunk app versions
  class SplunkVersion
    attr_reader :major
    attr_reader :minor
    attr_reader :patch
    attr_reader :meta

    def initialize(major, minor, patch = 0, meta = '', string = nil)
      @major = major.to_i
      @minor = minor.to_i
      @patch = patch.to_i
      @meta = meta
      @string = string if string

      return unless @meta[/\s/]
      @pre63 = true
      @meta = @meta.strip
    end

    def prerelease?
      !@meta.empty?
    end

    def pre_6_3?
      @pre63
    end

    def release_version
      @meta.empty? ? self : SplunkVersion.new(@major, @minor, @patch)
    end

    def to_s
      @string ||= '%{major}.%{minor}.%{patch}%{meta}' % { major: @major, minor: @minor, patch: @patch, meta: @meta }
    end

    def ==(other)
      to_s == other.to_s
    end

    # Compares two versions by major, minor, and patch version with consideration to prerelease versions
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def <=>(other)
      if self == other
        0
      elsif major != other.major
        major <=> other.major
      elsif minor != other.minor
        minor <=> other.minor
      elsif patch != other.patch
        patch <=> other.patch
      elsif !prerelease? # At this point, the versions are the same, but they have differing metadata
        1 # One of these versions is prerelease... And it's not self
      elsif !other.prerelease?
        -1 # One of these versions is prerelease... And it's not other
      else
        Chef::Log.warn("Attempted to compare two similar prerelease versions; metadata will not be compared (#{self} <=> #{other})")
        0
      end
    end

    class << self
      def from_string(string)
        version_matcher.match(string) do |m|
          return SplunkVersion.new(m[:major], m[:minor], m[:patch], m[:meta], string)
        end

        raise "Malformed version string: #{string}"
      end

      def version_matcher
        /^(?'major'\d+)\.(?'minor'\d+)(?:\.(?'patch'\d+))?(?'meta'.*)$/
      end
    end
  end
end
