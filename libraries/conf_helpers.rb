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
      evaluted_config = evaluate(config, context.freeze, current_config) || {}

      evaluted_config.merge(evaluted_config) do |section, props|
        (section_context = context.dup).section = section

        evaluted_props = evaluate(props, section_context.freeze, current_config.dig(section))
        next if evaluted_props.nil?

        evaluted_props.merge(evaluted_props) do |key, value|
          (key_context = section_context.dup).key = key
          evaluate(value, key_context.freeze, current_config.dig(section, key))
        end
      end
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
      current_section = 'default'
      current_config = {}

      conf_body.each_line do |ln|
        case ln
        when /^\s*\[([^#]+)\]\s*/
          current_section = Regexp.last_match[1]
        when /^\s*([^#]+?)\s*=\s*([^#]+?)\s*(?:#.*)?$/
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

      # Delete nil sections and values
      merged_config.delete_if do |section, props|
        next false unless desired_config.key? section
        next true if desired_config[section].nil?

        props.delete_if do |key, _|
          next false unless desired_config[section].key? key
          desired_config[section][key].nil?
        end

        false
      end

      stream = StringIO.new
      stream.puts '# Warning: This file is managed by Chef!'
      stream.puts '# Comments will not be preserved and configuration may be overwritten.'
      merged_config.each do |section, props|
        stream.puts ''
        stream.puts "[#{section}]"
        props.each { |key, value| stream.puts "#{key} = #{value}" }
      end
      stream.string
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
