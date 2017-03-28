# frozen_string_literal: true

module CernerSplunk
  # Helper methods for reading and evaluating Splunk config
  module ConfHelpers
    def self.evaluate_config(path, current_config, desired_config)
      context = ConfContext.new(path)
      desired_config = desired_config.call(context.freeze, current_config) if desired_config.is_a? Proc

      desired_config.map do |section, props|
        section_context = context.dup
        section_context.stanza = section
        mapout = props.is_a?(Proc) ? props.call(section_context.freeze, current_config[section] || {}) : [section, props]

        mapout[1] = mapout[1].map do |key, value|
          key_context = section_context.dup
          key_context.key = key
          value.is_a?(Proc) ? value.call(key_context.freeze, (current_config[section] || {})[key]) : [key, value]
        end.to_h

        mapout
      end.to_h
    end

    def self.stringify_config(config)
      config.map do |section, props|
        [section.to_s, props.map { |k, v| [k.to_s, v.to_s] }.to_h]
      end.to_h
    end

    def self.read_config(conf_path)
      conf_file = Pathname.new(conf_path)
      return {} unless conf_file.exist?

      parse_config(conf_file)
    end

    def self.parse_config(conf_body)
      current_stanza = 'default'
      current_config = {}

      conf_body.each_line do |ln|
        case ln
        when /^\s*\[([^#]+)\]\s*/
          current_stanza = Regexp.last_match[1]
        when /^\s*([^#]+?)\s*=\s*([^#]+?)\s*(?:#.*)?$/
          (current_config[current_stanza] ||= {})[Regexp.last_match[1]] = Regexp.last_match[2]
        end
      end

      current_config
    end

    def self.merge_config(current_config, desired_config)
      (current_config.keys + desired_config.keys).uniq.each do |section|
        (current_config[section] ||= {}).merge! desired_config[section] if desired_config[section]
      end

      stream = StringIO.new
      stream.puts '# Warning: This file is managed by Chef!'
      stream.puts '# Comments will not be preserved and configuration may be overwritten.'
      current_config.each do |section, props|
        stream.puts ''
        stream.puts "[#{section}]"
        props.each { |key, value| stream.puts "#{key} = #{value}" }
      end
      stream.string
    end

    class ConfContext
      attr_reader :path
      attr_reader :app
      attr_accessor :stanza
      attr_accessor :key

      def initialize(path, stanza = nil, key = nil)
        self.path = path
        self.stanza = stanza
        self.key = key
      end

      def path=(path)
        @path = path
        pathname = Pathname.new @path
        @app = /local|default|metadata$/.match(pathname.parent.to_s) && pathname.parent.parent.basename.to_s
      end

      def ==(other)
        other.path == @path && other.app == @app && other.stanza == @stanza && other.key == @key
      end
    end
  end unless defined?(ConfHelpers)
end
