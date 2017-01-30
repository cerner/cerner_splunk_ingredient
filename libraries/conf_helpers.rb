module CernerSplunk
  # Helper methods for reading and evaluating Splunk config
  module ConfHelpers
    def self.evaluate_config(current_config, desired_config)
      desired_config = desired_config.call(current_config) if desired_config.is_a? Proc
      desired_config.map do |section, props|
        mapout = props.is_a?(Proc) ? props.call(section, current_config[section] || {}) : [section, props]
        mapout[1] = mapout[1].map do |key, value|
          value.is_a?(Proc) ? value.call(key, (current_config[section] || {})[key]) : [key, value]
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
  end unless defined?(ConfHelpers)
end
