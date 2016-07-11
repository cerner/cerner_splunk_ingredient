require_relative '../spec_helper'

describe 'ResourceHelpers' do
  include CernerSplunk::ResourceHelpers
  describe 'load_installation_state' do
    let(:node) do
      node = Chef::Node.new
      node.automatic['os'] = 'linux'
      node.automatic['kernel'] = { 'machine' => 'x86_64' }
      node
    end

    let(:name) { 'splunk' }
    let(:install_dir) { '/opt/splunk' }
    let(:install_dir_path) { double('Pathname.new(install_dir)') }
    let(:splunk_bin_path) { double('bin') }
    let(:forwarder_app_path) { double('etc/apps/SplunkUniversalForwarder') }

    before do
      allow(Pathname).to receive(:new).with(install_dir).and_return(install_dir_path)
      allow(install_dir_path).to receive(:join).with('bin').and_return splunk_bin_path
      allow(install_dir_path).to receive(:join).with('etc/apps/SplunkUniversalForwarder').and_return forwarder_app_path

      allow(splunk_bin_path).to receive(:exist?).and_return true
      allow(forwarder_app_path).to receive(:exist?).and_return false

      version_double = double('splunk.version double')
      allow(version_double).to receive(:exist?).and_return(true)
      allow(version_double).to receive(:read).and_return("VERSION=6.3.4\nBUILD=cae2458f4aef")
      allow_any_instance_of(CernerSplunk::PathHelpers).to receive(:version_pathname).with(install_dir).and_return(version_double)
    end

    it 'should load the existing installation into run_state' do
      expect(load_installation_state).to be true
      expect(node.run_state['splunk_ingredient']['installations']).to eq(
        '/opt/splunk' => {
          'name' => 'splunk',
          'package' => :splunk,
          'version' => '6.3.4',
          'build' => 'cae2458f4aef',
          'x64' => true
        }
      )
    end

    context 'when universal forwarder app is detected' do
      it 'should load the installation into run_state as a universal_forwarder' do
        expect(forwarder_app_path).to receive(:exist?).and_return true
        expect(load_installation_state).to be true
        expect(node.run_state['splunk_ingredient']['installations']).to eq(
          '/opt/splunk' => {
            'name' => 'splunk',
            'package' => :universal_forwarder,
            'version' => '6.3.4',
            'build' => 'cae2458f4aef',
            'x64' => true
          }
        )
      end
    end

    context 'when the run_state is already loaded' do
      before do
        node.run_state['splunk_ingredient'] = self_state = { 'installations' => {} }
        self_state['installations']['/opt/splunk'] = {
          'name' => 'splunk',
          'package' => :splunk,
          'version' => '6.3.4',
          'build' => 'cae2458f4aef',
          'x64' => true
        }
      end
      it 'should not modify the run_state' do
        expect(install_dir_path).not_to receive(:join)
        expect(load_installation_state).to be true
      end
    end

    context 'when there is no existing installation' do
      it 'should not modify the run_state' do
        expect(splunk_bin_path).to receive(:exist?).and_return false
        expect(load_installation_state).to be false
        expect(node.run_state['splunk_ingredient']['installations']).to be_empty
      end
    end
  end
end
