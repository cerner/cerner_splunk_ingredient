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
  property :user, [String, nil]
  property :group, [String, nil], default: lazy { user }
  property :reset, [TrueClass, FalseClass], desired_state: false, default: false

  default_action :configure

  def existing_config(path)
    @cache ||= node.run_state['splunk_ingredient']['_cache'] ||= { 'existing_config' => {} }
    @cache['existing_config'][path.to_s] ||= read_config(path)
  end

  load_current_value do |desired|
    install_state = node.run_state['splunk_ingredient']['current_installation'] || {}

    desired.package = install_state['package'] unless property_is_set? :package
    package desired.package

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

    current_config = existing_config(desired.path)
    config reset ? current_config : current_config.select { |key, _| desired.config.keys.include? key.to_s }

    user current_owner
    desired.user ||= user
  end

  action :configure do
    config_user = user
    config_group = group

    splunk_service 'init_before_config' do
      package new_resource.package
      action :init
    end

    converge_if_changed :config do
      file new_resource.path.to_s do
        owner config_user
        group config_group
        content merge_config(reset ? {} : existing_config(new_resource.path), config)
      end
    end
  end
end
