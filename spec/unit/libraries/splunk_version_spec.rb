# frozen_string_literal: true
require 'rspec/its'
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
      let(:test_string) { '6.2 beta1' }
      let(:expected_version) { CernerSplunk::SplunkVersion.new(6, 2, nil, ' beta1', '6.2 beta1') }

      it { is_expected.to eq expected_version }
    end

    context 'with an invalid version' do
      let(:test_string) { '.3 garbage' }

      it 'should raise an error' do
        expect { subject }.to raise_error RuntimeError, 'Malformed version string: .3 garbage'
      end
    end
  end

  describe 'parameters' do
    context 'with minimum parameters' do
      subject { CernerSplunk::SplunkVersion.new(6, 3) }

      its(:major) { is_expected.to be 6 }
      its(:minor) { is_expected.to be 3 }
      its(:patch) { is_expected.to be 0 }
      its(:meta) { is_expected.to be_empty }
      it { is_expected.to eq '6.3.0' }

      its(:prerelease?) { is_expected.to be false }
      its(:pre_6_3?) { is_expected.to be false }
    end

    context 'with patch version' do
      subject { CernerSplunk::SplunkVersion.new(6, 3, 7) }

      its(:major) { is_expected.to be 6 }
      its(:minor) { is_expected.to be 3 }
      its(:patch) { is_expected.to be 7 }
      its(:meta) { is_expected.to be_empty }
      it { is_expected.to eq '6.3.7' }

      its(:prerelease?) { is_expected.to be false }
      its(:pre_6_3?) { is_expected.to be false }
    end

    context 'with metadata' do
      subject { CernerSplunk::SplunkVersion.new(6, 3, 0, 'beta1') }

      its(:major) { is_expected.to be 6 }
      its(:minor) { is_expected.to be 3 }
      its(:patch) { is_expected.to be 0 }
      its(:meta) { is_expected.to eq 'beta1' }
      it { is_expected.to eq '6.3.0beta1' }

      its(:prerelease?) { is_expected.to be true }
      its(:pre_6_3?) { is_expected.to be false }
    end

    context 'with string' do
      subject { CernerSplunk::SplunkVersion.new(6, 3, nil, 'beta1', '6.3beta1') }

      its(:major) { is_expected.to be 6 }
      its(:minor) { is_expected.to be 3 }
      its(:patch) { is_expected.to be 0 }
      its(:meta) { is_expected.to eq 'beta1' }
      it { is_expected.to eq '6.3beta1' }

      its(:prerelease?) { is_expected.to be true }
      its(:pre_6_3?) { is_expected.to be false }
    end

    context 'with pre 6.3 metadata' do
      subject { CernerSplunk::SplunkVersion.new(6, 3, 0, ' beta1') }

      its(:major) { is_expected.to be 6 }
      its(:minor) { is_expected.to be 3 }
      its(:patch) { is_expected.to be 0 }
      its(:meta) { is_expected.to eq 'beta1' }
      it { is_expected.to eq '6.3.0beta1' }

      its(:prerelease?) { is_expected.to be true }
      its(:pre_6_3?) { is_expected.to be true }
    end

    context 'with pre 6.3 metadata and string' do
      subject { CernerSplunk::SplunkVersion.new(6, 3, nil, ' beta1', '6.3 beta1') }

      its(:major) { is_expected.to be 6 }
      its(:minor) { is_expected.to be 3 }
      its(:patch) { is_expected.to be 0 }
      its(:meta) { is_expected.to eq 'beta1' }
      it { is_expected.to eq '6.3 beta1' }

      its(:prerelease?) { is_expected.to be true }
      its(:pre_6_3?) { is_expected.to be true }
    end

    context 'with bad string' do
      subject { CernerSplunk::SplunkVersion.new(6, 3, nil, 'beta1', '6.3 beta1') }

      it 'should raise an error' do
        expect { subject }.to raise_error RuntimeError, 'Given string does not match given version (6.3 beta1 vs. 6.3beta1)'
      end
    end
  end

  describe 'comparisons' do
    context 'without prerelease' do
      subject { CernerSplunk::SplunkVersion.new(1, 2, 3) }

      it { is_expected.to eq CernerSplunk::SplunkVersion.new(1, 2, 3) }
      it { is_expected.to be < CernerSplunk::SplunkVersion.new(4, 5, 6) }
      it { is_expected.to be < CernerSplunk::SplunkVersion.new(1, 5, 6) }
      it { is_expected.to be < CernerSplunk::SplunkVersion.new(1, 2, 6) }
    end

    context 'with prerelease' do
      subject { CernerSplunk::SplunkVersion.new(1, 2, 3, 'beta') }

      it { is_expected.to eq CernerSplunk::SplunkVersion.new(1, 2, 3, 'beta') }
      it { is_expected.to be < CernerSplunk::SplunkVersion.new(1, 2, 3) }
      it { is_expected.to be > CernerSplunk::SplunkVersion.new(1, 2, 0) }
    end
  end
end
