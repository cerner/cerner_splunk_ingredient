# frozen_string_literal: true
require_relative '../spec_helper'
require_relative '../../../libraries/splunk_version'

describe 'SplunkVersion' do
  describe 'self.from_string' do
    subject { CernerSplunk::SplunkVersion.from_string(test_string) }

    context 'without patch version' do
      let(:test_string) { '6.3.0' }
      let(:expected_version) { CernerSplunk::SplunkVersion.new(6, 3) }

      it { is_expected.to eq expected_version }
    end

    context 'with patch version' do
      let(:test_string) { '6.3.5' }
      let(:expected_version) { CernerSplunk::SplunkVersion.new(6, 3, 5) }

      it { is_expected.to eq expected_version }
    end

    context 'with pre-release metadata' do
      let(:test_string) { '6.3.5beta1' }
      let(:expected_version) { CernerSplunk::SplunkVersion.new(6, 3, 5, 'beta1') }

      it { is_expected.to eq expected_version }
    end

    context 'with Splunk < 6.3 pre-release metadata' do
      let(:test_string) { '6.3 beta1' }
      let(:expected_version) { CernerSplunk::SplunkVersion.new(6, 3, 0, ' beta1', '6.3 beta1') }

      it { is_expected.to eq expected_version }
    end

    context 'with an invalid version' do
      let(:test_string) { '.3 garbage' }

      it 'should raise an error' do
        expect { subject }.to raise_error RuntimeError, 'Malformed version string: .3 garbage'
      end
    end
  end
end
