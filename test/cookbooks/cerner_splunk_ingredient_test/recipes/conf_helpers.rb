my_config = {
  first: {
    blue: '0000FF',
    green: '00FF00',
    yes: true
  }
}

my_config_stringified = CernerSplunk::ConfHelpers.stringify_config(my_config)

config_output = CernerSplunk::ConfHelpers.merge_config(my_config, {})

parsed_config = CernerSplunk::ConfHelpers.parse_config(config_output)

unless parsed_config == my_config_stringified
  raise "Parsed config did not match stringified config: \
  #{parsed_config}\
  ...should be:
  #{my_config_stringified}"
end

file '/opt/my_config.conf' do
  content config_output
end
