require_relative '../spec_helper'

describe 'ServiceHelpers' do
  include CernerSplunk::ServiceHelpers

  describe 'service_pid' do
    let(:node) do
      node = Chef::Node.new
      node.automatic['os'] = 'linux'
      node.automatic['kernel'] = { 'machine' => 'x86_64' }
      node
    end

    let(:install_dir) { '/opt/splunk' }
    let(:install_dir_path) { double('Pathname.new(install_dir)') }
    let(:splunk_pid_path) { double('var/run/splunk/splunkd.pid') }

    before do
      node.run_state['splunk_ingredient'] = { 'installations' => {} }
    end

    context 'when the run state is loaded' do
      before do
        node.run_state['splunk_ingredient']['installations']['/opt/splunk'] = {
          'name' => 'splunk',
          'package' => :splunk,
          'version' => '6.3.4',
          'build' => 'cae2458f4aef',
          'x64' => true
        }

        expect(Pathname).to receive(:new).with(install_dir).and_return(install_dir_path)
        expect(install_dir_path).to receive(:join).with('var/run/splunk/splunkd.pid').and_return splunk_pid_path
      end

      context 'when the pid file exists' do
        before do
          expect(splunk_pid_path).to receive(:exist?).and_return true
        end

        it 'should read the pid from the file' do
          expect(splunk_pid_path).to receive(:readlines).and_return ['1000', '', '']
          expect(service_pid).to eq 1000
        end

        it 'should return nil if a valid pid is not read' do
          expect(splunk_pid_path).to receive(:readlines).and_return %w(abcd5 g g)
          expect(service_pid).to be_nil
        end
      end

      context 'when the pid file does not exist' do
        it 'should do nothing' do
          expect(splunk_pid_path).to receive(:exist?).and_return false
          expect(service_pid).to be_nil
        end
      end
    end

    context 'when the run state is not loaded' do
      it 'should do nothing' do
        expect(service_pid).to be_nil
      end
    end
  end
end
