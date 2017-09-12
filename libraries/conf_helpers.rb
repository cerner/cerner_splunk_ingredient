# frozen_string_literal: true

module CernerSplunk
  # Helper methods for reading and evaluating Splunk config
  module ConfHelpers
    private_class_method def self.evaluate(config, context, data)
      return config.call(context, data) if config.is_a?(Proc)
      config
    end

    def self.evaluate_config(path, current_config, config)
      context = ConfContext.new(path)
      evaluated_config = evaluate(config, context.freeze, current_config) || {}

      evaluated_config.merge(evaluated_config) do |section, props|
        (section_context = context.dup).section = section

        evaluated_props = evaluate(props, section_context.freeze, current_config.dig(section))
        next if evaluated_props.nil?

        evaluated_props.merge(evaluated_props) do |key, value|
          (key_context = section_context.dup).key = key
          evaluate(value, key_context.freeze, current_config.dig(section, key))
        end
      end
    end

    def self.stringify_config(config)
      config.map do |section, props|
        [section.to_s, props.map { |k, v| [k.to_s, v.nil? ? nil : v.to_s] }.to_h]
      end.to_h
    end

    def self.read_config(conf_path)
      conf_file = Pathname.new(conf_path)
      return {} unless conf_file.exist?

      parse_config(conf_file)
    end

    def self.parse_config(conf_body)
      current_section = 'default'
      current_config = {}

      conf_body.each_line do |ln|
        case ln
        when /^\s*\[([^#]+)\]\s*/
          current_section = Regexp.last_match[1]
          current_config[current_section] ||= {}
        when /^\s*([^#]+?)\s*=\s*([^#]*?)\s*(?:#.*)?$/
          (current_config[current_section] ||= {})[Regexp.last_match[1]] = Regexp.last_match[2]
        end
      end

      current_config
    end

    def self.merge_config(current_config, desired_config)
      merged_config = {}
      (current_config.keys + desired_config.keys).uniq.each do |section|
        merged_config[section] = (current_config[section] || {}).merge(desired_config[section] || {})
      end
      merged_config
    end

    def self.filter_config(config)
      config.delete_if do |_, props|
        next true if props.nil?
        props.delete_if { |_, value| value.nil? }
        false
      end
    end

    ##
    # Data object that provides contextual information when working within a Splunk .conf file.
    class ConfContext
      attr_reader :path
      attr_reader :app
      attr_accessor :section
      attr_accessor :key

      def initialize(path, section = nil, key = nil)
        self.path = path
        self.section = section
        self.key = key
      end

      def path=(path)
        @path = path
        pathname = Pathname.new @path
        @app = pathname.parent.parent.basename.to_s if %r{[/\\](?:local|default|metadata)$} =~ pathname.parent.to_s
      end

      def ==(other)
        other.path == @path && other.section == @section && other.key == @key
      end
    end
  end unless defined?(ConfHelpers)
end
