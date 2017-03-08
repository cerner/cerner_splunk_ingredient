# frozen_string_literal: true
module CernerSplunk
  # Mixin Helper methods for Splunk Ingredient resources' providers
  module ProviderHelpers
    def changed?(*properties)
      converge_if_changed(*properties) do
      end
    end

    module AppUpgrade
      def app_cache_path
        unless @app_cache_path
          @app_cache_path = Pathname.new(Chef::Config['file_cache_path']).join('splunk_ingredient/app_cache')
          [@app_cache_path, new_cache_path, existing_cache_path].each(&:mkpath)
        end

        @app_cache_path
      end

      private def existing_cache_path
        app_cache_path + 'current' + name
      end

      private def new_cache_path
        app_cache_path + 'new' + name
      end

      def backup_app
        converge_by 'backing up existing app' do # ~FC005
          FileUtils.cp_r(app_path, app_cache_path + 'current')
        end
      end

      def upgrade_keep_existing
        declare_resource(:directory, app_path.to_s) do
          action :nothing
          recursive true
        end.run_action :delete

        converge_by 'installing new app version' do
          FileUtils.mv(new_cache_path, app_path)
        end

        converge_by 'restoring local config' do
          existing_local = existing_cache_path + 'local'
          existing_local_meta = existing_cache_path + 'metadata/local.meta'
          new_local = new_cache_path + 'local'
          new_local_meta = new_cache_path + 'metadata/local.meta'

          new_local.mkpath && FileUtils.cp_r(existing_local, new_local) if existing_local.exist?
          new_local_meta.parent.mkpath && FileUtils.cp(existing_local_meta, new_local_meta) if existing_local_meta.exist?
        end

        converge_by "changing ownership of app to #{current_owner}:#{current_group}" do
          CernerSplunk::FileHelpers.deep_change_ownership(new_cache_path, current_owner, current_group)
        end
      end

      def validate_extracted_app
        # Check that the extracted app is the same name as the desired app.
        raise "Invalid or corrupt app package; could not find extracted app #{name} at #{new_cache_path}." unless new_cache_path.exist?

        # Check that the app does not contain local data
        return unless new_cache_path.join('local').exist? && !new_cache_path.join('local').children.empty? || new_cache_path.join('metadata/local.meta').exist?
        raise 'Downloaded app contains local data'
      end

      def validate_versions # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
        app_version = version
        pkg_app_conf = CernerSplunk::ConfHelpers.read_config(new_cache_path + 'default/app.conf')
        return true unless app_version && pkg_app_conf.key?('launcher')
        pkg_version = CernerSplunk::SplunkVersion.from_string(pkg_app_conf['launcher']['version'])

        # Check that the package's version matches the desired base version.
        unless pkg_version == app_version || !app_version.prerelease? && pkg_version.release_version == app_version.release_version
          raise "Downloaded app version does not match intended version to install (#{pkg_version} vs. #{version})"
        end

        # Check that the package's version is not a pre-release when we really expect a release
        if !app_version.prerelease? && pkg_version.prerelease?
          raise "Downloaded app version was unexpectedly a pre-release version (#{pkg_version} vs. #{app_Version})"
        end

        pkg_version != current_resource.version
      end
    end unless defined? AppUpgrade
  end
end
