module CernerSplunk
  # Mixin Helper methods for the Splunk Config resource
  module ConfHelpers
    def stringify_config(config)
      config.map do |section, props|
        [section.to_s, props.map { |k, v| [k.to_s, v.to_s] }.to_h]
      end.to_h
    end

    def read_config(conf_path)
      return {} unless Pathname.new(conf_path).exist?

      current_stanza = 'default'
      current_config = {}

      Pathname.new(conf_path).readlines.each do |ln|
        case ln
        when /^\s*\[(\w+)\]\s*$/
          current_stanza = Regexp.last_match[1]
        when /^\s*(\w+)\s*=\s*(.+)\s*$/
          (current_config[current_stanza] ||= {})[Regexp.last_match[1]] = Regexp.last_match[2]
        end
      end

      current_config
    end

    def resolve_types(config)
      config.merge config do |_, props|
        props.merge props do |_, value|
          case value
          when /^(true|false)$/
            value == 'true'
          when /^\d+$/
            Integer(value)
          when /^\d*\.\d+$/
            Float(value)
          else
            value
          end
        end
      end
    end

    def merge_config(desired_config, current_config)
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
  end
end
