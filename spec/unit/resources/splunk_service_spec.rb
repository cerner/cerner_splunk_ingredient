# frozen_string_literal: true

require_relative '../spec_helper'
include CernerSplunk::ServiceHelpers

shared_examples 'positive service examples' do |action, override_name|
  chef_context 'when splunk_service is created' do
    it { is_expected.to __guarded_restart_splunk_service(override_name || resource_name) }
  end

  it 'should delete the restart marker file' do
    expect(subject.service(service_name)).to notify("file[#{marker_path}]").to(:delete).immediately
  end

  case action
  when :start then it { is_expected.to start_service(service_name) }
  when :restart then it { is_expected.to restart_service(service_name) }
  when :stop then it { is_expected.to stop_service(service_name) }
  end
end

shared_examples '*start examples' do |action, platform, _, package|
  is_windows = platform == 'windows'
  let(:action_stubs) do
    expect_any_instance_of(Chef::Provider).not_to receive(:write_initd_ulimit)
  end

  include_examples 'positive service examples', action

  chef_context 'when the service has not been run for the first time' do
    let(:ftr_exists) { true }
    it { is_expected.to run_execute("#{cmd_prefix} enable boot-start#{is_windows ? '' : ' -user fauxhai'} --accept-license --no-prompt").with(cwd: "#{install_dir}/bin") }
    include_examples 'positive service examples', action
  end

  chef_context 'when install_dir is provided without package' do
    let(:install_dir) { platform == 'windows' ? 'C:\\Splunk' : '/etc/splunk' }
    let(:test_params) { { resource_name: resource_name, install_dir: install_dir, action: action } }
    include_examples 'positive service examples', action
  end

  chef_context 'when the package is provided as the name' do
    let(:test_params) { { resource_name: package.to_s, action: action } }
    include_examples 'positive service examples', action, package.to_s
  end

  unless is_windows
    chef_context 'when the ulimit is specified' do
      let(:test_params) { { resource_name: resource_name, package: package, action: action, ulimit: 4096 } }
      let(:action_stubs) do
        expect_any_instance_of(Chef::Provider).to receive(:service_running).at_least(:once).and_return(nil) if action == :start
        expect_any_instance_of(Chef::Provider).to receive(:write_initd_ulimit).with(4096)
      end

      it 'should delete the restart marker file' do
        expect(subject.service(service_name)).to notify("file[#{marker_path}]").to(:delete).immediately
      end
      it { is_expected.not_to desired_restart_splunk_service(service_name) }

      if action == :start
        chef_context 'when the service is running' do
          let(:action_stubs) do
            expect_any_instance_of(Chef::Provider).to receive(:service_running).at_least(:once).and_return(true)
            expect_any_instance_of(Chef::Provider).to receive(:write_initd_ulimit).with(4096)
          end

          it { is_expected.not_to delete_file(marker_path.to_s) }
          it { is_expected.to desired_restart_splunk_service(resource_name) }
        end
      end

      chef_context 'when the ulimit is the same' do
        let(:test_params) { { resource_name: resource_name, package: package, action: action, ulimit: 1024 } }
        let(:init_script_exists) { true }
        let(:action_stubs) do
          expect(init_script).to receive(:read).at_least(:once).and_return(IO.read('spec/reference/splunk_initd'))
          expect_any_instance_of(Chef::Provider).not_to receive(:service_running)
          expect_any_instance_of(Chef::Provider).not_to receive(:write_initd_ulimit)
        end

        it 'should delete the restart marker file' do
          expect(subject.service(service_name)).to notify("file[#{marker_path}]").to(:delete).immediately
        end
        it { is_expected.not_to desired_restart_splunk_service(resource_name) }
      end
    end
  end
end

describe 'splunk_service' do
  let(:test_resource) { 'splunk_service' }
  let(:test_recipe) { 'service_unit_test' }

  environment_combinations.each do |platform, version, package, _|
    context "on #{platform} #{version}" do
      context "with package #{package}" do
        let(:runner_params) { { platform: platform, version: version, user: 'root' } }
        is_windows = platform == 'windows'

        let(:has_run) { true }
        let(:ftr) { double('ftr_pathname') }
        let(:marker_double) { double('marker_path') }
        let(:init_script) { double('init_script_path') }
        let(:service_name) do
          if is_windows
            package == :splunk ? 'splunkd' : 'splunkforwarder'
          else
            'splunk'
          end
        end
        let(:cmd_prefix) { is_windows ? 'splunk.exe' : './splunk' }
        let(:install_dir) { CernerSplunk::PathHelpers.default_install_dirs[package][platform == 'windows' ? :windows : :linux] }
        let(:marker_path) { Pathname.new(install_dir) + 'restart_on_chef_client' }

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

        let(:ftr_exists) { false }
        let(:marker_exists) { false }
        let(:init_script_exists) { false }
        let(:common_stubs) do
          allow(CernerSplunk::PathHelpers).to receive(:ftr_pathname).and_return ftr
          allow(ftr).to receive(:exist?).and_return ftr_exists

          allow_any_instance_of(Chef::Provider).to receive(:marker_path).and_return marker_double
          allow(marker_double).to receive(:exist?).and_return marker_exists
          allow(marker_double).to receive(:to_s).and_return marker_path.to_s

          allow_any_instance_of(Chef::Provider).to receive(:current_owner).and_return(is_windows ? 'administrator' : 'fauxhai')
          allow_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
          unless is_windows
            allow_any_instance_of(Chef::Resource).to receive(:init_script_path).and_return(init_script)
            expect(init_script).to receive(:exist?).at_least(:once).and_return(init_script_exists)
          end
        end

        let(:chef_run_stubs) do
          common_stubs
          action_stubs
        end

        chef_describe 'action :start' do
          let(:resource_name) { 'start_service' }
          let(:test_params) { { resource_name: resource_name, package: package, action: :start } }
          include_examples '*start examples', :start, platform, version, package
        end

        chef_describe 'action :restart' do
          let(:resource_name) { 'restart_service' }
          let(:test_params) { { resource_name: resource_name, package: package, action: :restart } }
          include_examples '*start examples', :restart, platform, version, package
        end

        chef_describe 'action :stop' do
          let(:resource_name) { 'stop_service' }
          let(:action_stubs) {}
          let(:test_params) { { resource_name: resource_name, package: package, action: :stop } }
          include_examples 'positive service examples', :stop

          chef_context 'when the service has not been run for the first time' do
            let(:ftr_exists) { true }
            it { is_expected.not_to stop_service(service_name) }
          end

          chef_context 'when install_dir is provided without package' do
            let(:install_dir) { platform == 'windows' ? 'C:\\Splunk' : '/etc/splunk' }
            let(:test_params) { { resource_name: resource_name, install_dir: install_dir, action: :stop } }

            include_examples 'positive service examples', :stop
          end
        end

        chef_describe 'action :desired_restart' do
          let(:resource_name) { 'desired_restart' }
          let(:action_stubs) {}
          let(:test_params) { { resource_name: resource_name, package: package, action: :desired_restart } }

          it { is_expected.to create_file_if_missing(marker_path.to_s) }
        end

        chef_describe 'action :__guarded_restart' do
          let(:resource_name) { '__guarded_restart' }
          let(:action_stubs) {}
          let(:test_params) { { resource_name: resource_name, package: package, action: :__guarded_restart } }

          it { is_expected.not_to restart_splunk_service(resource_name) }

          chef_context 'when the restart marker is present' do
            let(:marker_exists) { true }
            it { is_expected.to restart_splunk_service(resource_name) }
            it 'should delete the restart marker file' do
              expect(subject.service(service_name)).to notify("file[#{marker_path}]").to(:delete).immediately
            end
          end
        end
      end
    end
  end
end
