# Cookbook Name:: cerner_splunk_ingredient
# Resource:: splunk_app
#
# Resource for installing and configuring Splunk apps

class SplunkApp < ChefCompat::Resource
  include CernerSplunk::PlatformHelpers, CernerSplunk::PathHelpers, CernerSplunk::ResourceHelpers

  property :name, String, name_property: true, identity: true
  property :install_dir, String, required: true, desired_state: false
  property :package, [:splunk, :universal_forwarder], required: true, desired_state: false
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
    @config_scope ||= (resource_name == :splunk_app_custom ? 'default' : 'local')
  end

  def splunk_app_path
    Pathname.new(install_dir).join('etc/apps')
  end

  def app_cache_path
    @app_cache_path ||= Pathname.new(Chef::Config['file_cache_path']).join('splunk_ingredient/old_apps')
  end

  def parse_meta_access(access)
    return access unless access.is_a? Hash
    access_read = Array(access[:read] || access['read']).join(', ')
    access_write = Array(access[:write] || access['write']).join(', ')
    "read : [ #{access_read} ], write : [ #{access_write} ]"
  end

  # Must be overridden by sub-resources
  def perform_upgrade
    raise "No upgrade implementation for current install scheme (#{resource_name})"
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

    app_conf = CernerSplunk::ConfHelpers.read_config(app_path.join('default/app.conf'))
    app_version = (app_conf['launcher'] ||= {})['version']
    if app_version
      raise 'Version to install must be specified when app has a version.' unless desired.version
      version app_version
    end
  end

  action_class do
    include CernerSplunk::ProviderHelpers

    def backup_existing_app
      directory app_cache_path.to_s do
        recursive true
        action :create
      end

      execute "mv #{app_path} #{app_cache_path + name}" do
        live_stream true
      end
    end

    def upgrade_app
      # Keep Existing strategy
      # TODO: Replace with deep copy
      execute "\\cp -r #{app_cache_path + name + 'local/*'} #{app_path + 'local'}" do
        live_stream true
      end

      execute "\\cp -r #{app_cache_path + name + 'metadata/local.meta'} #{app_path + 'metadata/local.meta'}" do
        live_stream true
      end
    end

    def apply_config
      node.run_state['splunk_ingredient']['conf_override'] = {
        conf_path: Pathname.new('apps').join(name).join(config_scope).to_s,
        install_dir: install_dir,
        scope: :none
      }

      instance_eval(&configs)
      node.run_state['splunk_ingredient']['conf_override'] = {}

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

class PackagedApp < SplunkApp
  property :source_url, String, required: true

  resource_name :splunk_app_package

  def package_path
    return @package_path if @package_path
    file_cache = Pathname.new(Chef::Config['file_cache_path'])
    @package_path = file_cache.join(CernerSplunk::PathHelpers.filename_from_url(source_url).gsub(/.spl$/, '.tgz'))
  end

  action :install do
    return unless !version || changed?(:version)

    remote_file package_path.to_s do
      source source_url
      show_progress true if defined? show_progress # Chef 12.9 feature
      notifies :delete, "remote_file[#{package_path}]", :delayed
    end

    directory app_path.to_s do
      action :create
    end

    backup_existing_app if version && changed?(:version)

    poise_archive package_path.to_s do
      destination app_path.to_s
      user current_owner
      group current_owner
    end

    upgrade_app if version && changed?(:version)

    apply_config
  end
end
