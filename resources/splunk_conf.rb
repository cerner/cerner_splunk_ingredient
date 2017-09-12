# frozen_string_literal: true

# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_conf
#
# Resource for managing Splunk configuration files

class SplunkConf < Chef::Resource
  include CernerSplunk::ResourceHelpers
  resource_name :splunk_conf

  property :path, [String, Pathname], name_property: true, desired_state: false, identity: true
  property :install_dir, String, required: true, desired_state: false
  property :package, %i[splunk universal_forwarder], required: true, desired_state: false
  property :scope, %i[local default none], desired_state: false, default: :local
  property :config, Hash, required: true
  property :user, String, default: lazy { current_owner }
  property :group, String, default: lazy { current_group }
  property :reset, [TrueClass, FalseClass], desired_state: false, default: false

  default_action :configure

  def after_created
    ((node.run_state['splunk_ingredient'] || {})['conf_override'] ||= {}).each do |key, value|
      send(key.to_sym, value)
    end
  end

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

  def conf_path(base_path)
    path((Pathname.new(base_path) + Pathname.new(path).basename).to_s)
  end

  load_current_value do |desired|
    if property_is_set? :install_dir
      install_dir desired.install_dir
      package desired.package = install_state['package']
    else
      current_state = node.run_state['splunk_ingredient']['current_installation'] || {}
      desired.package = current_state['package'] unless property_is_set? :package
      package desired.package
      install_dir desired.install_dir = (current_state['path'] || default_install_dir)
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
    end unless scope == :none

    desired.path = Pathname.new(install_dir) + 'etc' + real_path.sub(%r{^/}, '')
    unless @action.first == :delete
      current_config = existing_config(desired.path)

      evaluated_config = CernerSplunk::ConfHelpers.evaluate_config(desired.path, current_config, desired.config)
      desired.config = CernerSplunk::ConfHelpers.stringify_config(evaluated_config)

      config reset ? current_config : current_config.select { |key, _| desired.config.keys.include? key.to_s }
    end
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

    directory Pathname.new(path).parent.to_s do
      recursive true
      action :create
    end

    merged_config = CernerSplunk::ConfHelpers.merge_config(reset ? {} : existing_config(new_resource.path), config)

    template new_resource.path.to_s do # ~FC033 https://github.com/acrmp/foodcritic/issues/449
      source 'conf.erb'
      cookbook 'cerner_splunk_ingredient'
      owner config_user
      group config_group
      variables config: CernerSplunk::ConfHelpers.filter_config(merged_config)
    end if changed?(:config)
  end

  action :delete do
    template new_resource.path.to_s do
      action :delete
    end
  end
end
