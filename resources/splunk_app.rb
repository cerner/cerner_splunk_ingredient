# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_app
#
# Resource for installing and configuring Splunk apps

class SplunkApp < ChefCompat::Resource
  include CernerSplunk::PlatformHelpers, CernerSplunk::PathHelpers, CernerSplunk::ResourceHelpers

  resource_name :splunk_app

  property :name, String, name_property: true, identity: true
  property :install_dir, String, required: true, desired_state: false
  property :package, [:splunk, :universal_forwarder], required: true, desired_state: false
  property :source_url, String
  property :version, String
  property :configs, Proc
  property :files, Proc
  property :metadata, Hash, default: {}

  default_action :install

  def install_state
    unless @install_exists
      raise 'Attempted to reference service for Splunk installation that does not exist' unless load_installation_state
      @install_exists = true
    end

    node.run_state['splunk_ingredient']['installations'][install_dir]
  end

  def app_path
    @app_path ||= Pathname.new(splunk_app_path).join(name)
  end

  def config_scope
    'local'
  end

  def splunk_app_path
    Pathname.new(install_dir).join('etc/apps')
  end

  def parse_meta_access(access)
    return access unless access.is_a? Hash
    access_read = Array(access[:read] || access['read']).join(', ')
    access_write = Array(access[:write] || access['write']).join(', ')
    "read : [ #{access_read} ], write : [ #{access_write} ]"
  end

  ### Inherited Actions

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

    app_conf = CernerSplunk::ConfHelpers.read_config(app_path.join('local/app.conf'))
    app_version = (app_conf['launcher'] ||= {})['version']
    if app_version
      raise 'Version to install must be specified when app has a version.' unless desired.version
      version app_version
    end
  end

  action_class do
    include CernerSplunk::ProviderHelpers

    def apply_config
      node.run_state['splunk_ingredient']['conf_override'] = {
        conf_path: Pathname.new('apps').join(name).join(config_scope).to_s,
        install_dir: install_dir,
        scope: :none
      }

      instance_eval(&configs)
      ruby_block 'clear config overrides' do
        block do
          node.run_state['splunk_ingredient']['conf_override'] = {}
        end
      end

      instance_exec(app_path.to_s, &files)

      metadata.each do |_, props|
        access = props.delete(:access) || props.delete('access')
        props['access'] = parse_meta_access(access) unless access.to_s.empty?
      end

      splunk_conf Pathname.new('apps').join("#{name}/metadata/#{config_scope}.meta").to_s do
        scope :none
        config metadata
        reset true
      end
    end
  end

  action :uninstall do
    directory app_path.to_s do
      recursive true
      action :delete
    end
  end
end

###################################
### Platform Specific Resources ###
###################################

class CustomApp < SplunkApp
  resource_name :splunk_app_custom

  def config_scope
    'default'
  end

  action :install do
    return unless !version || changed?(:version)

    directory app_path.to_s do
      user current_owner
      group current_owner
      action :create
    end

    %w(default local lookups metadata).each do |subdir|
      directory app_path.join(subdir).to_s do
        user current_owner
        group current_owner
        action :create
      end
    end

    apply_config
  end
end
