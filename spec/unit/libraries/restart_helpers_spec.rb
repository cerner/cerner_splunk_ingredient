require_relative '../spec_helper'

describe 'RestartHelpers' do
  include CernerSplunk::RestartHelpers

  # Fake notifies method because we aren't using ChefSpec here.
  def notifies(*any)
  end

  let(:name) { 'splunk' }
  let(:install_dir) { '/opt/splunk' }
  let(:marker) { double('marker_path') }
  before do
    expect(self).to receive(:marker_path).and_return(marker).at_least :once
    allow(self).to receive(:resources)
  end

  describe 'ensure_restart' do
    it 'should create the restart marker' do
      expect(marker).to receive(:exist?).and_return false
      expect(marker).to receive(:open)
      expect(self).to receive(:notifies)
      ensure_restart
    end

    context 'when the marker exists' do
      it 'should not place the restart marker' do
        expect(marker).to receive(:exist?).and_return true
        expect(marker).not_to receive(:open)
        expect(self).to receive(:notifies)
        ensure_restart
      end
    end
  end

  describe 'check_restart' do
    it 'should not restart the splunk service' do
      expect(marker).to receive(:exist?).and_return false
      expect(self).not_to receive(:notifies)
      check_restart
    end

    context 'when the marker exists' do
      it 'should restart the splunk service' do
        expect(marker).to receive(:exist?).and_return true
        expect(self).to receive(:notifies)
        check_restart
      end
    end
  end

  describe 'clear_restart' do
    it 'should not delete the restart marker' do
      expect(marker).to receive(:exist?).and_return false
      expect(marker).not_to receive(:delete)
      clear_restart
    end

    context 'when the marker exists' do
      it 'should delete the restart marker' do
        expect(marker).to receive(:exist?).and_return true
        expect(marker).to receive(:delete)
        clear_restart
      end
    end
  end
end
