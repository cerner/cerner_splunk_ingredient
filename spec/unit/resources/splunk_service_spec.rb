require_relative '../spec_helper'

# TODO: Change how we're stubbing methods during refactoring so we can move this out of the global object space.
include CernerSplunk::ServiceHelpers, CernerSplunk::RestartHelpers

describe 'splunk_service' do
  let(:runner_params) { { platform: 'redhat', version: '7.1' } }
  let(:test_params) { { name: 'splunk', action: :nothing } }

  let(:mock_run_state) { { 'splunk_ingredient' => { 'installations' => {} } } }
  let(:chef_run) do
    ChefSpec::SoloRunner.new({ step_into: ['splunk_service'] }.merge!(runner_params)) do |node|
      node.normal['test_parameters'] = test_params
      node.normal['run_state'].merge!(mock_run_state)
    end.converge('cerner_splunk_ingredient_test::service_unit_test')
  end

  let(:ftr) { double('ftr_pathname') }
  let(:init_script) { double('init_script_path') }

  let(:run_state) { chef_run.node.run_state['splunk_ingredient'] }

  %w(start stop restart).each do |action|
    describe "with action :#{action}" do
      platform_package_matrix.select { |k, _| %w(windows redhat).include? k }.each do |platform, versions|
        versions.each do |version, packages|
          describe "on #{platform} #{version}" do
            packages.each do |package, _|
              context "with #{package}" do
                let(:runner_params) { { platform: platform, version: version, user: 'root' } }
                let(:test_params) { { name: package.to_s, action: action.to_sym } }
                let(:running) { false }
                is_windows = platform == 'windows'
                let(:service_name) do
                  if is_windows
                    package == :splunk ? 'splunkd' : 'splunkforwarder'
                  else
                    'splunk'
                  end
                end

                before do
                  allow_any_instance_of(Chef::Resource).to receive(:current_owner).and_return(is_windows ? nil : 'fauxhai')

                  allow_any_instance_of(Chef::Provider).to receive(:ftr_pathname).and_return ftr
                  allow(ftr).to receive(:exist?).and_return !running

                  expect_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
                  expect_any_instance_of(Chef::Resource).to receive(:check_restart)
                  allow_any_instance_of(Chef::Resource).to receive(:service_running).and_return(nil) unless is_windows

                  allow(init_script).to receive(:exist?).and_return(false)
                  allow_any_instance_of(Chef::Resource).to receive(:init_script_path).and_return(init_script)

                  expect_any_instance_of(Chef::Provider).to receive(:clear_restart) if action == 'restart'
                end

                let(:cmd_prefix) { is_windows ? 'splunk.exe' : './splunk' }

                context 'when the service has never been run' do
                  before do
                    expect_any_instance_of(Chef::Provider).not_to receive(:write_initd_ulimit)
                    expect_any_instance_of(Chef::Provider).not_to receive(:ensure_restart)
                  end

                  it "should #{action} the Splunk service" do
                    case action
                    when 'start'
                      expect(chef_run).to start_service(service_name)
                    when 'restart'
                      expect(chef_run).to restart_service(service_name)
                    end
                  end unless action == 'stop'

                  it 'should not stop the Splunk service' do
                    expect(chef_run).not_to stop_service(service_name)
                  end
                end

                context 'when the service is running' do
                  let(:running) { true }

                  before do
                    expect_any_instance_of(Chef::Provider).not_to receive(:write_initd_ulimit)
                    expect_any_instance_of(Chef::Provider).not_to receive(:ensure_restart)
                  end

                  it "should #{action} the Splunk service" do
                    case action
                    when 'start'
                      expect(chef_run).to start_service(service_name)
                    when 'stop'
                      expect(chef_run).to stop_service(service_name)
                    when 'restart'
                      expect(chef_run).to restart_service(service_name)
                    end
                  end
                end

                if platform == 'redhat' && %w(start restart).include?(action)
                  context 'when the ulimit is specified' do
                    let(:test_params) { { name: package.to_s, action: action.to_sym, ulimit: 4096 } }
                    let(:expected_command) { "sh -c 'ulimit -n 4096 && ./splunk #{splunk_command}'" }
                    it 'should set the ulimit' do
                      expect_any_instance_of(Chef::Provider).to receive(:write_initd_ulimit).with(4096)
                      chef_run
                    end

                    context 'when the service is running' do
                      let(:running) { true }
                      it 'should restart the service' do
                        expect_any_instance_of(Chef::Provider).to receive(:service_running).at_least(:once).and_return(true)
                        expect_any_instance_of(Chef::Provider).to receive(:ensure_restart)
                        expect_any_instance_of(Chef::Provider).to receive(:write_initd_ulimit).with(4096)
                        chef_run
                      end
                    end if action == 'start'

                    context 'when the ulimit is the same' do
                      before do
                        allow(init_script).to receive(:exist?).and_return(true)
                        allow(init_script).to receive(:read).and_return(IO.read('spec/reference/splunk_initd'))
                      end
                      let(:test_params) { { name: package.to_s, action: action.to_sym, ulimit: 1024 } }
                      it 'should not change the ulimit' do
                        expect_any_instance_of(Chef::Provider).not_to receive(:write_initd_ulimit)
                        expect(chef_run).not_to restart_splunk_service(package.to_s) if action == 'start'
                        chef_run
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
