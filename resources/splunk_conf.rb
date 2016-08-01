# splunk_conf '(app_name or system)/(file).conf' do
#   action :configure
#   package :splunk # Optional, can be :splunk or :universal_forwarder.
#   scope :local # Default, must be :local or :default
#   config {
#     'stanza': {
#       'key': 'value'
#     }
#   } # Defaults to empty hash, writing nothing. Hash of hashes, keyed by stanza and subsequent hashes containing string key value pairs.
#   reset false # Default, resets the conf file to defaults before writing changes.

# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_conf
#
# Resource for managing Splunk configuration files
class SplunkConf < ChefCompat::Resource
  include CernerSplunk::ConfHelpers, CernerSplunk::ResourceHelpers
  resource_name :splunk_conf

  property :path, [String, Pathname], name_property: true, desired_state: false, identity: true
  property :package, [:splunk, :universal_forwarder], required: true, desired_state: false
  property :scope, [:local, :default], desired_state: false, default: :local
  property :config, Hash, required: true
  property :user, [String, nil], default: lazy { current_owner }
  property :reset, [TrueClass, FalseClass], desired_state: false, default: false

  default_action :configure

  load_current_value do |desired|
    install_state = node.run_state['splunk_ingredient']['current_installation'] || {}
    if property_is_set? :package
      package desired.package
    else
      package install_state['package']
    end
    raise 'Attempted to reference Splunk installation that does not exist' unless load_installation_state

    real_path = Pathname.new(path)

    case real_path.dirname.to_s
    when /local$/
      scope :local
    when /default$/
      scope :default
    else
      real_path = real_path.dirname + scope.to_s + real_path.basename
    end

    desired.path = Pathname.new(install_dir).join('etc').join(real_path.sub(%r{^/}, ''))

    desired.config = stringify_config(desired.config)

    existing_config = read_config(desired.path)
    config reset ? existing_config : existing_config.select { |key, _| desired.config.keys.include? key.to_s }
  end

  action :configure do
    file new_resource.path do
      owner user
      action :create_if_missing
    end

    config_state = node.run_state['splunk_ingredient']['current_installation']['config'] ||= {}
    config_state[path.to_s[%r{^.+[\\/](.+[\\/].+[\\/].+)$}, 1]] = resolve_types(config)

    converge_if_changed :config do
      apply_config path, config, reset && {}
    end
  end
end
