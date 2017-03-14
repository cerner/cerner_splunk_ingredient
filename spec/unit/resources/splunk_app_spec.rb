# frozen_string_literal: true
require_relative '../spec_helper'
include CernerSplunk::ResourceHelpers

describe 'splunk_app' do
  let(:runner_params) { { platform: 'redhat', version: '7.1', user: 'root' } }
  let(:install_dir) { CernerSplunk::PathHelpers.default_install_dirs[:splunk][:linux] }
  let(:app_path) { Pathname.new("#{install_dir}/etc/apps/test_app") }
  let(:mock_run_state) do
    install = {
      name: 'splunk',
      package: :splunk,
      version: '6.3.4',
      build: 'cae2458f4aef',
      x64: true
    }
    {
      'splunk_ingredient' => {
        'installations' => {
          install_dir => install
        },
        'current_installation' => install
      }
    }
  end

  %w(splunk_app splunk_app_custom splunk_app_package).each do |resource|
    describe resource do
      let(:test_resource) { resource }
      let(:test_recipe) { 'app_unit_test' }

      let(:version_stub) do
        expect(CernerSplunk::ConfHelpers).to receive(:read_config).with(app_path + 'default/app.conf').and_return({})
      end

      let(:action_stubs) {}

      let(:chef_run_stubs) do
        allow_any_instance_of(Chef::Resource).to receive(:current_owner).and_return('splunk')
        allow_any_instance_of(Chef::Provider).to receive(:current_owner).and_return('splunk')
        allow_any_instance_of(Chef::Provider).to receive(:current_group).and_return('splunk')

        if resource == 'splunk_app_package'
          allow_any_instance_of(CernerSplunk::ProviderHelpers::AppUpgrade).to receive(:validate_extracted_app)
          allow_any_instance_of(CernerSplunk::ProviderHelpers::AppUpgrade).to receive(:validate_versions).and_return(upgrade)
        end

        version_stub
        action_stubs
      end

      let(:upgrade) { false }

      let(:app_cache_path) { './test/unit/.cache/splunk_ingredient/app_cache' }

      chef_describe 'action :install' do
        let(:action) { :install }

        let(:meta_conf) do
          {
            'default' => {
              'owner' => 'admin',
              'access' => { 'read' => '*', 'write' => 'admin' }
            },
            'views' => {
              'owner' => 'admin',
              'access' => { 'read' => '*', 'write' => %w(admin power) }
            }
          }
        end
        let(:expected_meta_conf) do
          {
            'default' => {
              'owner' => 'admin',
              'access' => 'read : [ * ], write : [ admin ]'
            },
            'views' => {
              'owner' => 'admin',
              'access' => 'read : [ * ], write : [ admin, power ]'
            }
          }
        end

        let(:configs_proc) do
          proc do
            splunk_conf 'test.conf' do
              config(abc: 123)
            end
          end
        end

        let(:files_proc) do
          proc do |path|
            file Pathname.new(path).join('testing.txt').to_s do
              content 'Unimportant Text'
            end
          end
        end

        let(:source_url) do
          case resource
          when 'splunk_app_package' then 'http://fake/my_app.spl'
          end
        end

        let(:test_params) do
          {
            name: 'test_app',
            configs: configs_proc,
            source_url: source_url,
            files: files_proc,
            metadata: meta_conf,
            action: action
          }
        end

        let(:scope) { resource == 'splunk_app_custom' ? 'default' : 'local' }

        shared_examples 'app install' do
          chef_context 'installing the app' do
            let(:action_stubs) {}
            case resource
            when 'splunk_app_package'
              let(:package_path) { Pathname.new(app_cache_path) + 'my_app.tgz' }
              let(:existing_cache_path) { Pathname.new(app_cache_path) + 'current' }
              let(:new_cache_path) { Pathname.new(app_cache_path) + 'new' }
              let(:action_stubs) do
                if upgrade
                  # Backup App
                  expect(FileUtils).to receive(:cp_r).with(app_path, existing_cache_path)
                end
              end
              it do
                if upgrade
                  is_expected.to run_ruby_block('upgrade app')
                else
                  is_expected.not_to run_ruby_block('upgrade app')
                end
              end
              it { is_expected.to create_remote_file(package_path).with(source: source_url) }
              it { is_expected.to unpack_poise_archive(package_path).with(destination: new_cache_path.to_s) }
            when 'splunk_app_custom'
              let(:directory_params) { { owner: 'splunk', group: 'splunk' } }
              it { is_expected.to create_directory(app_path.to_s).with(directory_params) }
              it { is_expected.to create_directory("#{app_path}/default").with(directory_params) }
              it { is_expected.to create_directory("#{app_path}/local").with(directory_params) }
              it { is_expected.to create_directory("#{app_path}/lookups").with(directory_params) }
              it { is_expected.to create_directory("#{app_path}/metadata").with(directory_params) }
            end

            it { is_expected.to configure_splunk('test.conf').with(config: { abc: 123 }) }
            it { is_expected.to create_file("#{app_path}/testing.txt").with(content: 'Unimportant Text') }
            it { is_expected.to configure_splunk("apps/test_app/metadata/#{scope}.meta").with(scope: :none, config: expected_meta_conf, reset: true) }
          end
        end

        shared_examples 'app no-install' do
          chef_context 'not installing the app' do
            case resource
            when 'splunk_app_package'
              let(:package_path) { Pathname.new(app_cache_path) + 'my_app.tgz' }
              it { is_expected.not_to run_ruby_block('upgrade app') }
              it { is_expected.not_to create_remote_file(package_path) }
              it { is_expected.not_to unpack_poise_archive(package_path) }
            when 'splunk_app_custom'
              it { is_expected.not_to create_directory(app_path.to_s) }
              it { is_expected.not_to create_directory("#{app_path}/default") }
              it { is_expected.not_to create_directory("#{app_path}/local") }
              it { is_expected.not_to create_directory("#{app_path}/lookups") }
              it { is_expected.not_to create_directory("#{app_path}/metadata") }
            end

            it { is_expected.not_to configure_splunk('test.conf') }
            it { is_expected.not_to create_file("#{app_path}/testing.txt") }
            it { is_expected.not_to configure_splunk("apps/test_app/metadata/#{scope}.meta") }
          end
        end

        include_examples 'app install'

        chef_context 'when metadata[:access] does not exist' do
          let(:meta_conf) do
            {
              'default' => {
                'owner' => 'admin',
                'access' => { 'read' => '*', 'write' => 'admin' }
              },
              'views' => {
                'owner' => 'admin'
              }
            }
          end
          let(:expected_meta_conf) do
            {
              'default' => {
                'owner' => 'admin',
                'access' => 'read : [ * ], write : [ admin ]'
              },
              'views' => {
                'owner' => 'admin'
              }
            }
          end

          it { is_expected.to configure_splunk("apps/test_app/metadata/#{scope}.meta").with(scope: :none, config: expected_meta_conf, reset: true) }
        end

        chef_context 'when metadata[:access] is not a hash' do
          let(:meta_conf) do
            {
              'default' => {
                'owner' => 'admin',
                'access' => 'read : [ * ], write : [ admin ]'
              },
              'views' => {
                'owner' => 'admin'
              }
            }
          end
          let(:expected_meta_conf) do
            {
              'default' => {
                'owner' => 'admin',
                'access' => 'read : [ * ], write : [ admin ]'
              },
              'views' => {
                'owner' => 'admin'
              }
            }
          end

          it { is_expected.to configure_splunk("apps/test_app/metadata/#{scope}.meta").with(scope: :none, config: expected_meta_conf, reset: true) }
        end

        chef_context 'when metadata is not given' do
          let(:test_params) do
            {
              name: 'test_app',
              configs: configs_proc,
              source_url: source_url,
              files: files_proc,
              action: action
            }
          end

          it { is_expected.to configure_splunk("apps/test_app/metadata/#{scope}.meta").with(scope: :none, config: {}, reset: true) }
        end

        chef_context 'when install_dir is provided' do
          let(:install_dir) { '/etc/splunk' }
          let(:test_params) do
            {
              name: 'test_app',
              install_dir: install_dir,
              configs: configs_proc,
              source_url: source_url,
              files: files_proc,
              metadata: meta_conf,
              action: action
            }
          end

          include_examples 'app install'
        end

        chef_context 'when package is provided' do
          let(:test_params) do
            {
              name: 'test_app',
              package: :splunk,
              configs: configs_proc,
              source_url: source_url,
              files: files_proc,
              metadata: meta_conf,
              action: action
            }
          end

          include_examples 'app install'
        end

        chef_context 'without a prior install' do
          let(:mock_run_state) do
            install = {
              name: 'splunk',
              package: :splunk,
              version: '6.3.4',
              build: 'cae2458f4aef',
              x64: true
            }
            {
              'splunk_ingredient' => {
                'installations' => {
                  install_dir => install
                }
              }
            }
          end

          chef_context 'without install_dir or package' do
            let(:chef_run_stubs) {}

            it 'should fail the chef run' do
              expect { chef_run }.to raise_error Chef::Exceptions::ValidationFailed, /package is required$/
            end
          end

          chef_context 'when install_dir is provided' do
            let(:install_dir) { '/etc/splunk' }
            let(:test_params) do
              {
                name: 'test_app',
                install_dir: install_dir,
                configs: configs_proc,
                source_url: source_url,
                files: files_proc,
                metadata: meta_conf,
                action: action
              }
            end

            include_examples 'app install'
          end

          chef_context 'when package is provided' do
            let(:test_params) do
              {
                name: 'test_app',
                package: :splunk,
                configs: configs_proc,
                source_url: source_url,
                files: files_proc,
                metadata: meta_conf,
                action: action
              }
            end

            include_examples 'app install'
          end
        end

        chef_context 'when app.conf provides a version' do
          let(:version_config) { { 'launcher' => { 'version' => '1.0.0' } } }
          let(:version_stub) do
            expect(CernerSplunk::ConfHelpers).to receive(:read_config).with(app_path + 'default/app.conf').and_return(version_config)
          end

          chef_context 'when version is provided' do
            let(:upgrade) { true }
            let(:test_params) do
              {
                name: 'test_app',
                version: '2.0.0',
                configs: configs_proc,
                source_url: source_url,
                files: files_proc,
                metadata: meta_conf,
                action: action
              }
            end

            include_examples 'app install'

            chef_context 'when version is the same' do
              let(:version_config) { { 'launcher' => { 'version' => '2.0.0' } } }

              include_examples 'app no-install'
            end
          end

          chef_context 'when version is not provided' do
            it 'should fail the chef run' do
              expect { chef_run }.to raise_error RuntimeError, /Version to install must be specified when app has a version.$/
            end
          end
        end

        chef_context 'when app.conf does not provide a version' do
          chef_context 'when version is provided' do
            let(:upgrade) { true }
            let(:test_params) do
              {
                name: 'test_app',
                version: '2.0.0',
                configs: configs_proc,
                source_url: source_url,
                files: files_proc,
                metadata: meta_conf,
                action: action
              }
            end

            include_examples 'app install'
          end
        end
      end unless resource == 'splunk_app'

      chef_describe 'action :uninstall' do
        let(:action) { :uninstall }
        let(:chef_run_stubs) { {} }
        let(:test_params) do
          {
            name: 'test_app',
            action: action
          }
        end

        it { is_expected.to delete_directory(app_path.to_s) }

        chef_context 'when install_dir is provided' do
          let(:install_dir) { '/etc/splunk' }
          let(:test_params) do
            {
              name: 'test_app',
              install_dir: install_dir,
              action: action
            }
          end

          it { is_expected.to delete_directory(app_path.to_s) }
        end

        chef_context 'when package is provided' do
          let(:test_params) do
            {
              name: 'test_app',
              package: :splunk,
              action: action
            }
          end

          it { is_expected.to delete_directory(app_path.to_s) }
        end

        chef_context 'without a prior install' do
          let(:mock_run_state) do
            install = {
              name: 'splunk',
              package: :splunk,
              version: '6.3.4',
              build: 'cae2458f4aef',
              x64: true
            }
            {
              'splunk_ingredient' => {
                'installations' => {
                  install_dir => install
                }
              }
            }
          end

          chef_context 'without install_dir or package' do
            it 'should fail the chef run' do
              expect { chef_run }.to raise_error Chef::Exceptions::ValidationFailed, /package is required$/
            end
          end

          chef_context 'when install_dir is provided' do
            let(:install_dir) { '/etc/splunk' }
            let(:test_params) do
              {
                name: 'test_app',
                install_dir: install_dir,
                action: action
              }
            end

            it { is_expected.to delete_directory(app_path.to_s) }
          end

          chef_context 'when package is provided' do
            let(:test_params) do
              {
                name: 'test_app',
                package: :splunk,
                action: action
              }
            end

            it { is_expected.to delete_directory(app_path.to_s) }
          end
        end
      end
    end
  end
end
