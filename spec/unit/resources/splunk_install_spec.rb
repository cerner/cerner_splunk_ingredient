require_relative '../spec_helper'
require_relative 'install_examples'

describe 'splunk_install' do
  include CernerSplunk::PathHelpers, CernerSplunk::PlatformHelpers

  let(:runner_params) { { platform: 'redhat', version: '7.1' } }
  let(:test_params) { { name: 'splunk', build: 'cae2458f4aef', version: '6.3.4' } }

  let(:windows_opts) { 'LAUNCHSPLUNK=0 INSTALL_SHORTCUT=0 AGREETOLICENSE=Yes' }

  let(:mock_run_state) { { 'splunk_ingredient' => { 'installations' => {} } } }
  let(:chef_run) do
    ChefSpec::SoloRunner.new({ step_into: ['splunk_install'] }.merge!(runner_params)) do |node|
      node.normal['test_parameters'] = test_params
      node.normal['run_state'].merge!(mock_run_state)
    end.converge('cerner_splunk_ingredient_test::install_unit_test')
  end

  before do
    allow_any_instance_of(Chef::Resource).to receive(:current_owner).and_return('fauxhai')
  end

  let(:run_state) { chef_run.node.run_state['splunk_ingredient'] }

  describe 'action :install' do
    before do
      allow_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return false
      allow_any_instance_of(Chef::Provider).to receive(:load_version_state)
    end
    platform_package_matrix.each do |platform, versions|
      versions.each do |version, packages|
        describe "on #{platform} #{version}" do
          packages.each do |package, expected_url|
            include_examples 'standard install', platform, version, package, expected_url
          end
        end
      end
    end

    context 'with a non-package name' do
      let(:test_params) { { name: 'Logmaster', package: :universal_forwarder, build: 'cae2458f4aef', version: '6.3.4' } }

      it 'should install' do
        expect(chef_run).to install_rpm_package('splunkforwarder')
      end
    end

    context 'with base_url' do
      let(:expected_url) do
        'https://repo.internet.website/splunk/universalforwarder/releases/6.3.4/linux/splunkforwarder-6.3.4-cae2458f4aef-linux-2.6-x86_64.rpm'
      end
      let(:package_path) { "./test/unit/.cache/#{filename_from_url(expected_url)}" }
      let(:test_params) do
        {
          package: :universal_forwarder,
          build: 'cae2458f4aef',
          version: '6.3.4',
          base_url: 'https://repo.internet.website/splunk'
        }
      end

      it 'should download the package' do
        expect(chef_run).to create_remote_file(package_path).with(source: expected_url)
      end
    end

    context 'when package is not specified' do
      let(:test_params) { { name: 'hotcakes', build: 'cae2458f4aef', version: '6.3.4' } }

      it 'should fail the Chef run' do
        expect { chef_run }.to raise_error(RuntimeError, /Package must be specified.*/)
      end
    end

    context 'when version is not specified' do
      let(:test_params) { { build: 'cae2458f4aef' } }

      it 'should fail the Chef run' do
        expect { chef_run }.to raise_error(Chef::Exceptions::ValidationFailed, /.* version is required/)
      end
    end

    context 'when build is not specified' do
      let(:test_params) { { version: '6.3.4' } }

      it 'should fail the Chef run' do
        expect { chef_run }.to raise_error(Chef::Exceptions::ValidationFailed, /.* build is required/)
      end
    end

    context 'when platform is not supported' do
      let(:runner_params) { { platform: 'aix', version: '7.1' } }
      let(:test_params) { { name: 'splunk', build: 'cae2458f4aef', version: '6.3.4' } }

      it 'should fail the Chef run' do
        expect { chef_run }.to raise_error(RuntimeError, /Unsupported Combination.*/)
      end
    end
  end

  describe 'action :uninstall' do
    before do
      allow_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
      allow_any_instance_of(Chef::Provider).to receive(:load_version_state)
    end
    platform_package_matrix.each do |platform, versions|
      versions.each do |version, packages|
        context "on #{platform} #{version}" do
          packages.each do |package, _|
            include_examples 'standard uninstall', platform, version, package
          end
        end
      end
    end

    context 'when package is not specified' do
      let(:test_params) { { name: 'hotcakes', action: :uninstall } }
      it 'should fail the Chef run' do
        expect { chef_run }.to raise_error(RuntimeError, /Package must be specified.*/)
      end
    end
  end
end
