require_relative '../spec_helper'
require_relative 'install_examples'

describe 'splunk_install' do
  include CernerSplunk::PlatformHelpers

  let(:test_resource) { 'splunk_install' }
  let(:test_recipe) { 'install_unit_test' }

  environment_combinations.each do |platform, version, package, expected_url|
    context "on #{platform} #{version}" do
      context "with package #{package}" do
        let(:runner_params) { { platform: platform, version: version, user: 'root' } }

        let(:test_params) { { resource_name: 'splunk', build: 'cae2458f4aef', version: '6.3.4' } }
        let(:mock_run_state) { { 'splunk_ingredient' => { 'installations' => {} } } }

        let(:package_name) { package_names[package][platform == 'windows' ? :windows : :linux] }
        let(:install_dir) { CernerSplunk::PathHelpers.default_install_dirs[package][platform == 'windows' ? :windows : :linux] }
        let(:windows_opts) { 'LAUNCHSPLUNK=0 INSTALL_SHORTCUT=0 AGREETOLICENSE=Yes' }
        let(:command_prefix) { platform == 'windows' ? 'splunk.exe' : './splunk' }

        let(:common_stubs) do
          allow_any_instance_of(Chef::Resource).to receive(:current_owner).and_return('root')
        end

        let(:chef_run_stubs) do
          common_stubs
          action_stubs
        end

        chef_describe 'action :install' do
          let(:action_stubs) do
            allow_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return false
          end

          include_examples 'standard install', platform, package, expected_url

          if [platform, package] == ['redhat', :universal_forwarder]
            chef_context 'with a non-package name' do
              let(:test_params) do
                {
                  name: 'Logmaster',
                  package: :universal_forwarder,
                  build: 'cae2458f4aef',
                  version: '6.3.4'
                }
              end

              it { is_expected.to install_rpm_package('splunkforwarder') }
            end

            chef_context 'with base_url' do
              let(:test_params) do
                {
                  package: :universal_forwarder,
                  build: 'cae2458f4aef',
                  version: '6.3.4',
                  base_url: 'https://repo.internet.website/splunk'
                }
              end
              let(:base_expected_url) do
                'https://repo.internet.website/splunk/universalforwarder/releases/6.3.4/linux/splunkforwarder-6.3.4-cae2458f4aef-linux-2.6-x86_64.rpm'
              end
              let(:package_path) { "./test/unit/.cache/#{CernerSplunk::PathHelpers.filename_from_url(expected_url)}" }

              it { is_expected.to create_remote_file(package_path).with(source: base_expected_url) }
            end
          end

          chef_context 'when the user is specified' do
            let(:test_params) { { resource_name: package.to_s, build: 'cae2458f4aef', version: '6.3.4', user: 'fauxhai' } }

            it { is_expected.to run_execute "chown -R fauxhai:fauxhai #{install_dir}" }
            chef_context 'when the group is specified' do
              let(:test_params) { { resource_name: package.to_s, build: 'cae2458f4aef', version: '6.3.4', user: 'fauxhai', group: 'grouphai' } }

              it { is_expected.to run_execute "chown -R fauxhai:grouphai #{install_dir}" }
            end
          end if platform != 'windows'

          chef_context 'when package is not specified' do
            let(:test_params) { { resource_name: 'hotcakes', build: 'cae2458f4aef', version: '6.3.4' } }

            it 'should fail the Chef run' do
              expect { subject }.to raise_error(RuntimeError, /Package must be specified.*/)
            end
          end

          chef_context 'when version is not specified' do
            let(:test_params) { { build: 'cae2458f4aef' } }

            it 'should fail the Chef run' do
              expect { subject }.to raise_error(Chef::Exceptions::ValidationFailed, /.* version is required/)
            end
          end

          chef_context 'when build is not specified' do
            let(:test_params) { { version: '6.3.4' } }

            it 'should fail the Chef run' do
              expect { subject }.to raise_error(Chef::Exceptions::ValidationFailed, /.* build is required/)
            end
          end

          chef_context 'when platform is not supported' do
            let(:runner_params) { { platform: 'aix', version: '7.1' } }
            let(:test_params) { { resource_name: 'splunk', build: 'cae2458f4aef', version: '6.3.4' } }

            it 'should fail the Chef run' do
              expect { subject }.to raise_error(RuntimeError, /Unsupported Combination.*/)
            end
          end
        end

        chef_describe 'action :uninstall' do
          let(:action_stubs) do
            allow_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
          end

          include_examples 'standard uninstall', platform, package

          chef_context 'when package is not specified' do
            let(:test_params) { { resource_name: 'hotcakes', action: :uninstall } }

            it 'should fail the Chef run' do
              expect { subject }.to raise_error(RuntimeError, /Package must be specified.*/)
            end
          end
        end
      end
    end
  end
end
