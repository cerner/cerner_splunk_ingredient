require_relative '../spec_helper'
include CernerSplunk::ServiceHelpers, CernerSplunk::RestartHelpers

shared_examples '*start examples' do |action, platform, _, package|
  is_windows = platform == 'windows'
  let(:action_stubs) do
    expect_any_instance_of(Chef::Provider).not_to receive(:write_initd_ulimit)
    expect_any_instance_of(Chef::Provider).not_to receive(:ensure_restart)
  end

  case action
  when :start
    it { is_expected.to start_service(service_name) }
  when :restart
    it { is_expected.to restart_service(service_name) }
  end

  chef_context 'when the service has not been run for the first time' do
    let(:ftr_exists) { true }
    let(:action_stubs) do
      expect_any_instance_of(Chef::Provider).not_to receive(:write_initd_ulimit)
      expect_any_instance_of(Chef::Provider).not_to receive(:ensure_restart)
    end

    case action
    when :start
      it { is_expected.to start_service(service_name) }
    when :restart
      it { is_expected.to restart_service(service_name) }
    end
  end

  unless is_windows
    chef_context 'when the ulimit is specified' do
      let!(:original_stubs) { action_stubs }

      let(:test_params) { { name: package.to_s, action: action, ulimit: 4096 } }
      let(:action_stubs) do
        expect_any_instance_of(Chef::Provider).to receive(:service_running).and_return(nil) if action == :start
        expect_any_instance_of(Chef::Provider).to receive(:write_initd_ulimit).with(4096)
        expect_any_instance_of(Chef::Provider).not_to receive(:ensure_restart)
      end

      it 'should set the ulimit' do
        subject
      end

      chef_context 'when the service is running' do
        let(:action_stubs) do
          expect_any_instance_of(Chef::Provider).to receive(:service_running).at_least(:once).and_return(true)
          expect_any_instance_of(Chef::Provider).to receive(:write_initd_ulimit).with(4096)
          expect_any_instance_of(Chef::Provider).to receive(:ensure_restart)
        end

        it 'should ensure a service restart' do
          subject
        end
      end if action == :start

      chef_context 'when the ulimit is the same' do
        let(:test_params) { { name: package.to_s, action: action, ulimit: 1024 } }
        let(:init_script_exists) { true }
        let(:action_stubs) do
          expect(init_script).to receive(:read).and_return(IO.read('spec/reference/splunk_initd'))
          expect_any_instance_of(Chef::Provider).not_to receive(:service_running)
          expect_any_instance_of(Chef::Provider).not_to receive(:write_initd_ulimit)
          expect_any_instance_of(Chef::Provider).not_to receive(:ensure_restart)
        end

        it 'should not change the ulimit' do
          subject
        end
      end
    end
  end
end

describe 'splunk_service' do
  let(:test_resource) { 'splunk_service' }
  let(:test_recipe) { 'service_unit_test' }

  environment_combinations.each do |platform, version, package, _|
    describe "on #{platform} #{version}" do
      describe "with package #{package}" do
        let(:runner_params) { { platform: platform, version: version, user: 'root' } }
        is_windows = platform == 'windows'

        let(:has_run) { true }
        let(:ftr) { double('ftr_pathname') }
        let(:init_script) { double('init_script_path') }
        let(:service_name) do
          if is_windows
            package == :splunk ? 'splunkd' : 'splunkforwarder'
          else
            'splunk'
          end
        end
        let(:cmd_prefix) { is_windows ? 'splunk.exe' : './splunk' }

        let(:mock_run_state) { { 'splunk_ingredient' => { 'installations' => {} } } }

        let(:ftr_exists) { false }
        let(:init_script_exists) { false }
        let(:ftr_scope) { Chef::Resource }
        let(:common_stubs) do
          expect_any_instance_of(Chef::Resource).to receive(:check_restart)
          expect_any_instance_of(ftr_scope).to receive(:ftr_pathname).and_return ftr
          expect(ftr).to receive(:exist?).and_return ftr_exists

          expect_any_instance_of(Chef::Resource).to receive(:current_owner).and_return(is_windows ? nil : 'fauxhai')
          expect_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
          unless is_windows
            expect_any_instance_of(Chef::Resource).to receive(:init_script_path).at_least(:once).and_return(init_script)
            expect(init_script).to receive(:exist?).and_return init_script_exists
          end
        end

        let(:chef_run_stubs) do
          common_stubs
          action_stubs
        end

        chef_context 'action :start' do
          let(:test_params) { { name: package.to_s, action: :start } }
          include_examples '*start examples', :start, platform, version, package
        end

        chef_context 'action :restart' do
          let(:test_params) { { name: package.to_s, action: :restart } }
          include_examples '*start examples', :restart, platform, version, package
        end

        chef_context 'action :stop' do
          let(:action_stubs) {}
          let(:ftr_scope) { Chef::Provider }
          let(:test_params) { { name: package.to_s, action: :stop } }

          it { is_expected.to stop_service(service_name) }

          chef_context 'when the service has not been run for the first time' do
            let(:ftr_exists) { true }
            it { is_expected.not_to stop_service(service_name) }
          end
        end
      end
    end
  end
end
