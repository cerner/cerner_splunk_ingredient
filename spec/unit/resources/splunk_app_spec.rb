require_relative '../spec_helper'
include CernerSplunk::ResourceHelpers

describe 'splunk_app' do
  let(:runner_params) { { platform: 'redhat', version: '7.1', user: 'root' } }
  let(:install_dir) { CernerSplunk::PathHelpers.default_install_dirs[:splunk][:linux] }
  let(:app_path) { "#{install_dir}/etc/apps/test_app" }
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

  # %w(splunk_app_custom splunk_app_package splunk_app_git).each do |resource, test|
  %w(splunk_app_custom).each do |resource|
    describe resource do
      let(:test_resource) { resource }
      let(:test_recipe) { 'app_unit_test' }

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

        let(:configs_double) { double('configs') }
        let(:configs_proc) do
          -> { configs_double.call }
        end

        let(:files_double) { double('files') }
        let(:files_proc) do
          ->(path) { files_double.call(path) }
        end

        let(:proc_stubs) do
          expect(configs_double).to receive(:call)
          expect(files_double).to receive(:call).with(app_path)
        end

        let(:version_stub) do
          expect(CernerSplunk::ConfHelpers).to receive(:read_config).with(Pathname.new(app_path).join('local/app.conf')).and_return({})
        end

        let(:chef_run_stubs) do
          allow_any_instance_of(Chef::Resource).to receive(:current_owner).and_return('splunk')
          proc_stubs
          version_stub
        end

        let(:test_params) do
          {
            name: 'test_app',
            configs: configs_proc,
            files: files_proc,
            metadata: meta_conf,
            action: action
          }
        end

        let(:scope) { resource == 'splunk_app_custom' ? 'default' : 'local' }

        shared_examples 'app_install' do
          case resource
          when 'splunk_app_custom'
            let(:directory_params) { { owner: 'splunk', group: 'splunk' } }
            it { is_expected.to create_directory(app_path).with(directory_params) }
            it { is_expected.to create_directory("#{app_path}/default").with(directory_params) }
            it { is_expected.to create_directory("#{app_path}/local").with(directory_params) }
            it { is_expected.to create_directory("#{app_path}/lookups").with(directory_params) }
            it { is_expected.to create_directory("#{app_path}/metadata").with(directory_params) }
          end

          it { is_expected.to configure_splunk("#{app_path}/metadata/#{scope}.meta").with(scope: :none, config: expected_meta_conf, reset: true) }
        end

        shared_examples 'app_no_install' do
          let(:proc_stubs) {}

          case resource
          when 'splunk_app_custom'
            it { is_expected.not_to create_directory(app_path) }
            it { is_expected.not_to create_directory("#{app_path}/default") }
            it { is_expected.not_to create_directory("#{app_path}/local") }
            it { is_expected.not_to create_directory("#{app_path}/lookups") }
            it { is_expected.not_to create_directory("#{app_path}/metadata") }
          end

          it { is_expected.not_to configure_splunk("#{app_path}/metadata/#{scope}.meta") }
        end

        include_examples 'app_install'

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

          it { is_expected.to configure_splunk("#{app_path}/metadata/#{scope}.meta").with(scope: :none, config: expected_meta_conf, reset: true) }
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

          it { is_expected.to configure_splunk("#{app_path}/metadata/#{scope}.meta").with(scope: :none, config: expected_meta_conf, reset: true) }
        end

        chef_context 'when metadata is not given' do
          let(:test_params) do
            {
              name: 'test_app',
              configs: configs_proc,
              files: files_proc,
              action: action
            }
          end

          it { is_expected.to configure_splunk("#{app_path}/metadata/#{scope}.meta").with(scope: :none, config: {}, reset: true) }
        end

        chef_context 'when install_dir is provided' do
          let(:install_dir) { '/etc/splunk' }
          let(:test_params) do
            {
              name: 'test_app',
              install_dir: install_dir,
              configs: configs_proc,
              files: files_proc,
              metadata: meta_conf,
              action: action
            }
          end

          include_examples 'app_install'
        end

        chef_context 'when package is provided' do
          let(:test_params) do
            {
              name: 'test_app',
              package: :splunk,
              configs: configs_proc,
              files: files_proc,
              metadata: meta_conf,
              action: action
            }
          end

          include_examples 'app_install'
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
              expect { subject }.to raise_error Chef::Exceptions::ValidationFailed, /package is required$/
            end
          end

          chef_context 'when install_dir is provided' do
            let(:install_dir) { '/etc/splunk' }
            let(:test_params) do
              {
                name: 'test_app',
                install_dir: install_dir,
                configs: configs_proc,
                files: files_proc,
                metadata: meta_conf,
                action: action
              }
            end

            include_examples 'app_install'
          end

          chef_context 'when package is provided' do
            let(:test_params) do
              {
                name: 'test_app',
                package: :splunk,
                configs: configs_proc,
                files: files_proc,
                metadata: meta_conf,
                action: action
              }
            end

            include_examples 'app_install'
          end
        end

        chef_context 'when app.conf provides a version' do
          let(:version_config) { { 'launcher' => { 'version' => '1.0.0' } } }
          let(:version_stub) do
            expect(CernerSplunk::ConfHelpers).to receive(:read_config).with(Pathname.new(app_path).join('local/app.conf')).and_return(version_config)
          end

          chef_context 'when version is provided' do
            let(:test_params) do
              {
                name: 'test_app',
                version: '2.0.0',
                configs: configs_proc,
                files: files_proc,
                metadata: meta_conf,
                action: action
              }
            end

            include_examples 'app_install'

            chef_context 'when version is the same' do
              let(:version_config) { { 'launcher' => { 'version' => '2.0.0' } } }

              include_examples 'app_no_install'
            end
          end
          chef_context 'when version is not provided' do
            let(:proc_stubs) {}
            it 'should fail the chef run' do
              expect { subject }.to raise_error RuntimeError, /Version to install must be specified when app has a version.$/
            end
          end
        end

        chef_context 'when app.conf does not provide a version' do
          chef_context 'when version is provided' do
            let(:test_params) do
              {
                name: 'test_app',
                version: '2.0.0',
                configs: configs_proc,
                files: files_proc,
                metadata: meta_conf,
                action: action
              }
            end

            include_examples 'app_install'
          end
        end
      end

      chef_describe 'action :uninstall' do
        let(:action) { :uninstall }
        let(:chef_run_stubs) { {} }
        let(:test_params) do
          {
            name: 'test_app',
            action: action
          }
        end

        it { is_expected.to delete_directory(app_path) }

        chef_context 'when install_dir is provided' do
          let(:install_dir) { '/etc/splunk' }
          let(:test_params) do
            {
              name: 'test_app',
              install_dir: install_dir,
              action: action
            }
          end

          it { is_expected.to delete_directory(app_path) }
        end

        chef_context 'when package is provided' do
          let(:test_params) do
            {
              name: 'test_app',
              package: :splunk,
              action: action
            }
          end

          it { is_expected.to delete_directory(app_path) }
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
              expect { subject }.to raise_error Chef::Exceptions::ValidationFailed, /package is required$/
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

            it { is_expected.to delete_directory(app_path) }
          end

          chef_context 'when package is provided' do
            let(:test_params) do
              {
                name: 'test_app',
                package: :splunk,
                action: action
              }
            end

            it { is_expected.to delete_directory(app_path) }
          end
        end
      end
    end
  end
end
