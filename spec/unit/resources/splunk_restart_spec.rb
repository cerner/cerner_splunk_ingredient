require_relative '../spec_helper'
include CernerSplunk::RestartHelpers

describe 'splunk_restart' do
  let(:test_resource) { 'splunk_restart' }
  let(:test_recipe) { 'restart_unit_test' }

  environment_combinations.each do |platform, version, package, _|
    context "on #{platform} #{version}" do
      context "with package #{package}" do
        let(:runner_params) { { platform: platform, version: version, user: 'root' } }

        let(:install_dir) { default_install_dirs[package][platform == 'windows' ? :windows : :linux] }
        let(:mock_run_state) { { 'splunk_ingredient' => { 'installations' => {} } } }

        let(:common_stubs) do
          expect_any_instance_of(Chef::Resource).to receive(:load_installation_state).and_return true
        end

        let(:chef_run_stubs) do
          common_stubs
          action_stubs
        end

        chef_describe 'action :ensure' do
          let(:test_params) { { name: package.to_s, action: :ensure } }
          let(:action_stubs) {}
          it { is_expected.to create_file_if_missing(Pathname.new(install_dir).join('restart_on_chef_client').to_s) }

          it 'should notify the Splunk service to restart' do
            expect(subject.splunk_restart(package.to_s)).to notify("splunk_service[#{package}]").to(:restart).delayed
          end
        end

        chef_describe 'action :check' do
          let(:test_params) { { name: package.to_s, action: :check } }

          chef_context 'when the marker exists' do
            let(:action_stubs) do
              marker = double('marker_path')
              expect_any_instance_of(Chef::Provider).to receive(:marker_path).and_return(marker)
              expect(marker).to receive(:exist?).and_return true
            end

            it 'should notify the Splunk service to restart' do
              expect(subject.splunk_restart(package.to_s)).to notify("splunk_service[#{package}]").to(:restart).delayed
            end
          end

          chef_context 'when the marker does not exist' do
            let(:action_stubs) do
              marker = double('marker_path')
              expect_any_instance_of(Chef::Provider).to receive(:marker_path).and_return(marker)
              expect(marker).to receive(:exist?).and_return false
            end

            it 'should not notify the Splunk service to restart' do
              expect(subject.splunk_restart(package.to_s)).not_to notify("splunk_service[#{package}]")
            end
          end
        end

        chef_describe 'action :clear' do
          let(:test_params) { { name: package.to_s, action: :clear } }
          let(:action_stubs) {}

          it { is_expected.to delete_file(Pathname.new(install_dir).join('restart_on_chef_client').to_s) }
        end
      end
    end
  end
end
