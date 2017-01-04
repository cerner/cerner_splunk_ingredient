# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_conf
#
# Resource for managing Splunk configuration files

class SplunkConf < ChefCompat::Resource
  include CernerSplunk::ResourceHelpers
  resource_name :splunk_conf

  property :path, [String, Pathname], name_property: true, desired_state: false, identity: true
  property :install_dir, String, required: true, desired_state: false
  property :package, [:splunk, :universal_forwarder], required: true, desired_state: false
  property :scope, [:local, :default], desired_state: false, default: :local
  property :config, Hash, required: true
  property :user, [String, nil]
  property :group, [String, nil], default: lazy { user }
  property :reset, [TrueClass, FalseClass], desired_state: false, default: false

  default_action :configure

  def install_state
    unless @install_exists
      raise 'Attempted to reference service for Splunk installation that does not exist' unless load_installation_state
      @install_exists = true
    end

    node.run_state['splunk_ingredient']['installations'][install_dir]
  end

  def release_config_cache(path)
    @cache ||= node.run_state['splunk_ingredient']['_cache'] ||= { 'existing_config' => {} }
    @cache['existing_config'].delete(path.to_s)
  end

  def existing_config(path)
    @cache ||= node.run_state['splunk_ingredient']['_cache'] ||= { 'existing_config' => {} }
    @cache['existing_config'][path.to_s] ||= CernerSplunk::ConfHelpers.read_config(path)
  end

  load_current_value do |desired|
    if property_is_set? :install_dir
      install_dir desired.install_dir
      package desired.package = install_state['package']
    else
      current_state = node.run_state['splunk_ingredient']['current_installation'] || {}
      desired.package = current_state['package'] unless property_is_set? :package
      package desired.package
      install_dir desired.install_dir = default_install_dir
      install_state
    end

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
    current_config = existing_config(desired.path)

    evaluated_config = CernerSplunk::ConfHelpers.evaluate_config(current_config, desired.config)
    desired.config = CernerSplunk::ConfHelpers.stringify_config(evaluated_config)

    config reset ? current_config : current_config.select { |key, _| desired.config.keys.include? key.to_s }

    user current_owner
    desired.user ||= user
  end

  action_class do
    include CernerSplunk::ProviderHelpers
  end

  action :configure do
    config_user = user
    config_group = group

    splunk_service 'init_before_config' do
      install_dir new_resource.install_dir
      action :init
      notifies :run, 'ruby_block[Wipe cache after initialization]', :immediately
    end

    ruby_block 'Wipe cache after initialization' do
      block do
        release_config_cache(path)
      end
      action :nothing
    end

    file new_resource.path.to_s do
      owner config_user
      group config_group
      content CernerSplunk::ConfHelpers.merge_config(reset ? {} : existing_config(new_resource.path), config)
    end if changed?(:config)
  end
end
