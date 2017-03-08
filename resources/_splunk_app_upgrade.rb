# frozen_string_literal: true
# Cookbook Name:: cerner_splunk_ingredient
# Resource:: _splunk_app_upgrade
#
# Resource for installing and configuring Splunk apps

class SplunkAppUpgrade < Chef::Resource
  include CernerSplunk::PlatformHelpers, CernerSplunk::PathHelpers, CernerSplunk::ResourceHelpers

  property :name, String, name_property: true, identity: true
  property :install_dir, String, required: true
  property :version, [String, CernerSplunk::SplunkVersion], required: true

  resource_name :_splunk_app_upgrade

  default_action :nothing

  def after_created
    version CernerSplunk::SplunkVersion.from_string(version) if version
  end

  def app_path
    @app_path ||= Pathname.new(splunk_app_path).join(name)
  end

  # Provider exclusive methods

  action_class do
    require 'fileutils'
    include CernerSplunk::ProviderHelpers

    def app_cache_path
      unless @app_cache_path
        @app_cache_path = Pathname.new(Chef::Config['file_cache_path']).join('splunk_ingredient/app_cache')
        directory @app_cache_path.to_s do
          action :create
          recursive true
        end

        directory new_cache_path.to_s do
          action :create
          recursive true
        end

        directory existing_cache_path.to_s do
          action :create
          recursive true
        end
      end

      @app_cache_path
    end

    def existing_cache_path
      app_cache_path + 'current' + name
    end

    def new_cache_path
      app_cache_path + 'new' + name
    end

    def validate_versions # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
      pkg_app_conf = CernerSplunk::ConfHelpers.read_config(new_cache_path + 'default/app.conf')
      return true unless version && pkg_app_conf.key?('launcher')
      pkg_version = CernerSplunk::SplunkVersion.from_string(pkg_app_conf['launcher']['version'])

      # Check that the package's version matches the desired base version.
      unless pkg_version == version || !version.prerelease? && pkg_version.release_version == version.release_version
        raise "Downloaded app version does not match intended version to install (#{pkg_version} vs. #{version})"
      end

      # Check that the package's version is not a pre-release when we really expect a release
      if !version.prerelease? && pkg_version.prerelase
        raise "Downloaded app version was unexpectedly a pre-release version (#{pkg_version} vs. #{version})"
      end

      pkg_version != version
    end
  end

  ### Inherited Actions

  action :backup do
    directory existing_cache_path.to_s do
      recursive true
      action :create
    end

    FileUtils.cp_r(app_path, existing_cache_path)
  end

  action :upgrade do
    # Check that the extracted app is the same name as the desired app.
    raise "Invalid or corrupted app; could not find app #{name}." unless new_cache_path.exist?

    # Check that the app does not contain local data
    raise 'Downloaded app contains local data' if new_cache_path.join('local').exist? || new_cache_path.join('metadata/local.meta').exist?

    return unless validate_versions

    directory app_path.to_s do
      action :delete
      recursive true
    end

    FileUtils.mv(new_cache_path, app_path)
    FileUtils.cp_r(existing_cache_path + 'local', app_path + 'local')
    FileUtils.cp(existing_cache_path + 'metadata/local.meta', app_path + 'metadata/local.meta')

    CernerSplunk::FileHelpers.deep_change_ownership(app_path, current_owner, current_group)
  end

  action :cleanup do
    directory @app_cache_path.to_s do
      action :delete
      recursive true
    end

    directory new_cache_path.to_s do
      action :delete
      recursive true
    end

    directory existing_cache_path.to_s do
      action :delete
      recursive true
    end
  end
end
