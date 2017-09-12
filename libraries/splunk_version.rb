# frozen_string_literal: true

module CernerSplunk
  # Class object for parsing and encapsulating Splunk app versions
  class SplunkVersion
    include Comparable

    attr_reader :major
    attr_reader :minor
    attr_reader :patch
    attr_reader :meta

    def initialize(major, minor, patch = nil, meta = '', string = nil)
      @major = major.to_i
      @minor = minor.to_i
      @patch = patch.to_i if patch
      @meta = meta

      if string
        raise "Given string does not match given version (#{string} vs. #{self})" unless self == string
        @string = string
      end

      @patch ||= 0

      return unless @meta[/\s/]
      @pre63 = true
      @meta = @meta.strip
    end

    def prerelease?
      !@meta.empty?
    end

    def pre_6_3?
      !@pre63.nil?
    end

    def release_version
      SplunkVersion.new(@major, @minor, @patch)
    end

    def to_s
      @string ||= '%<major>s.%<minor>s%<patch_dot>s%<patch>s%<meta>s' % {
        major: @major,
        minor: @minor,
        patch_dot: @patch.nil? ? '' : '.',
        patch: @patch,
        meta: @meta
      }
    end

    def ==(other)
      to_s == other.to_s
    end

    # Compares two versions by major, minor, and patch version with consideration to prerelease versions
    def <=>(other)
      return 0 if self == other

      release_comp = compare_release_version(other)
      release_comp.zero? && compare_prerelease(other) || release_comp
    end

    private

    def compare_release_version(other)
      if major != other.major
        major <=> other.major
      elsif minor != other.minor
        minor <=> other.minor
      elsif patch != other.patch
        patch <=> other.patch
      else
        0
      end
    end

    def compare_prerelease(other)
      if prerelease? && other.prerelease?
        Chef::Log.warn("Attempted to compare two similar prerelease versions (#{self} <=> #{other})")
        0
      elsif prerelease?
        -1
      elsif other.prerelease?
        1
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
