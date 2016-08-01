
require_relative '../spec_helper'

include CernerSplunk::ConfHelpers, CernerSplunk::ResourceHelpers

shared_examples 'splunk_conf' do |platform, version, package|
  describe 'action :configure' do
    let(:runner_params) { { platform: platform, version: version, user: 'root' } }
    let(:config) { { 'a' => { 'foo' => 'bar', 'one' => 1 } } }
    let(:action) { :configure }

    let(:install_dir) { default_install_dirs[package][platform == 'windows' ? :windows : :linux] }
    let(:mock_run_state) do
      install = {
        name: package.to_s,
        package: package,
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

    let(:chef_run_stubs) do
      expect_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
      expect_any_instance_of(Chef::Resource).to receive(:read_config).with(conf_path).and_return({})
      allow_any_instance_of(Chef::Resource).to receive(:current_owner).and_return(platform == 'windows' ? nil : 'fauxhai')

      expect_any_instance_of(Chef::Provider).to receive(:apply_config).with(conf_path, config, false)
    end

    let(:conf_path) { Pathname.new(install_dir) + 'etc/system/local/test.conf' }

    context 'when all parameters provided' do
      let(:conf_path) { Pathname.new(install_dir) + 'etc/system/default/test.conf' }
      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          scope: :default,
          config: config,
          user: package.to_s,
          action: action
        }
      end

      let(:expected_params) do
        {
          path: conf_path,
          package: package,
          scope: :default,
          config: config,
          user: package.to_s
        }
      end

      it { is_expected.to configure_splunk('system/test.conf').with expected_params }

      it 'should set the run state' do
        run_state = chef_run.node.run_state['splunk_ingredient']['current_installation']
        expect(run_state['config']['system/default/test.conf']).to eq config
      end
    end

    context 'when scope is not provided' do
      let(:test_params) do
        {
          path: 'system/local/test.conf',
          package: package,
          config: config,
          user: package.to_s,
          action: action
        }
      end

      it { is_expected.to configure_splunk('system/local/test.conf') }

      context 'when the path does not include scope' do
        let(:test_params) do
          {
            path: 'system/test.conf',
            package: package,
            config: config,
            user: package.to_s,
            action: action
          }
        end

        it { is_expected.to configure_splunk('system/test.conf').with scope: :local }
      end
    end

    context 'when package is not provided' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          scope: :local,
          config: config,
          user: package.to_s,
          action: action
        }
      end

      it { is_expected.to configure_splunk('system/test.conf') }

      context 'without a prior install' do
        let(:chef_run_stubs) {}
        let(:mock_run_state) do
          install = {
            name: package.to_s,
            package: package,
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

        it 'should fail the chef run' do
          expect { chef_run }.to raise_error Chef::Exceptions::ValidationFailed, /package is required$/
        end
      end
    end

    context 'when config is not provided' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          scope: :local,
          user: package.to_s,
          action: action
        }
      end
      let(:chef_run_stubs) {}

      it 'should fail the chef run' do
        expect { chef_run }.to raise_error Chef::Exceptions::ValidationFailed, /config is required$/
      end

      context 'when reset is specified' do
        let(:test_params) do
          {
            path: 'system/test.conf',
            scope: :local,
            user: package.to_s,
            action: action,
            reset: true
          }
        end

        it 'should fail the chef run' do
          expect { chef_run }.to raise_error Chef::Exceptions::ValidationFailed, /config is required$/
        end
      end
    end

    context 'when user is not specified' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          scope: :local,
          config: config,
          action: action
        }
      end

      it { is_expected.to configure_splunk('system/test.conf').with user: platform == 'windows' ? nil : 'fauxhai' }
    end

    context 'when reset is specified' do
      let(:test_params) do
        {
          path: 'system/test.conf',
          package: package,
          user: package.to_s,
          scope: :local,
          config: config,
          reset: true,
          action: action
        }
      end
      let(:chef_run_stubs) do
        expect_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
        expect_any_instance_of(Chef::Resource).to receive(:read_config).with(conf_path).and_return({})
        allow_any_instance_of(Chef::Resource).to receive(:current_owner).and_return(platform == 'windows' ? nil : 'fauxhai')

        expect_any_instance_of(Chef::Provider).to receive(:apply_config).with(conf_path, config, {})
      end

      it { is_expected.to configure_splunk('system/test.conf') }
    end
  end
end

describe 'splunk_conf' do
  include CernerSplunk::PathHelpers

  let(:mock_run_state) { { 'splunk_ingredient' => { 'installations' => {} } } }
  let(:chef_run_stubs) {}

  let(:chef_run) do
    ChefSpec::SoloRunner.new({ step_into: ['splunk_conf'] }.merge!(runner_params)) do |node|
      node.normal['test_parameters'] = test_params
      node.normal['run_state'].merge!(mock_run_state)
      chef_run_stubs
    end.converge('cerner_splunk_ingredient_test::config_unit_test')
  end

  let(:run_state) { chef_run.node.run_state['splunk_ingredient'] }

  subject { chef_run }

  environment_combinations.each do |platform, version, package, _|
    describe "on #{platform} #{version}" do
      describe "with package #{package}" do
        include_examples 'splunk_conf', platform, version, package
      end
    end
  end
end
