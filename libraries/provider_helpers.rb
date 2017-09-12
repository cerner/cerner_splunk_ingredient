# frozen_string_literal: true

module CernerSplunk
  # Mixin Helper methods for Splunk Ingredient resources' providers
  module ProviderHelpers
    # Logic copied from Chef::Provider#converge_if_changed
    def changed?(*properties)
      properties = new_resource.class.state_properties.map(&:name) if properties.empty?
      properties = properties.map(&:to_sym)
      if current_resource
        specified_properties = properties.select { |property| new_resource.property_is_set?(property) }
        modified = specified_properties.reject { |p| new_resource.send(p) == current_resource.send(p) }
        return false if modified.empty?
      end
      true
    end

    module AppUpgrade
      def app_cache_path
        unless @app_cache_path
          @app_cache_path = Pathname.new(Chef::Config['file_cache_path']) + 'splunk_ingredient/app_cache'
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

      def app_installed?
        app_path.exist?
      end

      def backup_app
        ruby_resource = ruby_block 'backing up existing app' do
          block do
            FileUtils.cp_r(app_path, app_cache_path + 'current')
          end
        end

        # Necessary to prevent this from causing the app resource to be 'updated'
        def ruby_resource.updated?
          false
        end
      end

      def upgrade_keep_existing
        converge_by 'restoring local config' do # ~FC005
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

        declare_resource(:directory, app_path.to_s) do
          action :nothing
          recursive true
        end.run_action :delete

        converge_by 'installing new app version' do
          FileUtils.mv(new_cache_path, app_path)
        end
      end

      def validate_extracted_app
        # Check that the extracted app is the same name as the desired app.
        raise "Invalid or corrupt app package; could not find extracted app #{name} at #{new_cache_path}." unless new_cache_path.exist?

        @pkg_app_conf ||= CernerSplunk::ConfHelpers.read_config(new_cache_path + 'default/app.conf')

        raise 'Packaged app must have a version' unless @pkg_app_conf.dig('launcher', 'version')

        # Check that the app does not contain local data
        return unless (new_cache_path + 'local').exist? && !(new_cache_path + 'local').children.empty? || (new_cache_path + 'metadata/local.meta').exist?
        raise 'Downloaded app contains local data'
      end

      def validate_versions
        desired_version = version
        @pkg_app_conf ||= CernerSplunk::ConfHelpers.read_config(new_cache_path + 'default/app.conf')

        # If the version is not specified, or the version does not exist in the currently installed app, then continue to install.
        return true unless desired_version && current_resource.version

        pkg_version = CernerSplunk::SplunkVersion.from_string(@pkg_app_conf['launcher']['version'])

        # Check that the package's version matches the desired base version.
        unless pkg_version == desired_version || !desired_version.prerelease? && pkg_version.release_version == desired_version.release_version
          raise "Downloaded app version does not match intended version to install (#{pkg_version} vs. #{version})"
        end

        pkg_version != current_resource.version
      end
    end unless defined? AppUpgrade
  end
end
