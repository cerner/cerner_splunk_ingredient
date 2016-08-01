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
      config.update config do |_, props|
        props.update props do |_, value|
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

    def apply_config(conf_path, desired_config, current_config = nil)
      conf_file = Pathname.new(conf_path)
      conf_file.open('a', &:close)

      current_config || current_config = read_config(conf_path)

      (current_config.keys + desired_config.keys).uniq.each do |section|
        (current_config[section] ||= {}).merge! desired_config[section] if desired_config[section]
      end

      conf_file.open('w') do |file|
        file.puts '# Warning: This file is managed by Chef!'
        file.puts '# Comments will not be preserved and configuration may be overwritten.'
        current_config.each do |section, props|
          file.puts ''
          file.puts "[#{section}]"
          props.each { |key, value| file.puts "#{key} = #{value}" }
        end
      end
    end
  end
end
