# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ConfHelpers' do
  let(:conf_path) { '/opt/splunk/etc/system/local/test.conf' }
  let(:existing_config) do
    {
      'default' => {
        'first' => 'true',
        'second' => 'true'
      },
      'other' => {
        'something' => 'here'
      }
    }
  end

  describe 'evaluate_config' do
    subject { CernerSplunk::ConfHelpers.evaluate_config(conf_path, existing_config, config) }

    context 'with top-level proc' do
      let!(:actual_context) {}
      let(:config) do
        lambda do |context, conf|
          conf.merge('context' => { 'context' => context })
        end
      end
      let(:expected_context) { CernerSplunk::ConfHelpers::ConfContext.new(conf_path) }
      let(:expected_config) do
        {
          'context' => { 'context' => expected_context },
          'default' => {
            'first' => 'true',
            'second' => 'true'
          },
          'other' => {
            'something' => 'here'
          }
        }
      end

      it { is_expected.to eq(expected_config) }
    end

    context 'with section-level proc' do
      let(:config) do
        {
          'default' => {
            'second' => 'false'
          },
          'other' => ->(context, props) { props.merge('context' => context) }
        }
      end
      let(:expected_context) { CernerSplunk::ConfHelpers::ConfContext.new(conf_path, 'other') }
      let(:expected_config) do
        {
          'default' => {
            'second' => 'false'
          },
          'other' => {
            'context' => expected_context,
            'something' => 'here'
          }
        }
      end

      it { is_expected.to eq(expected_config) }
    end

    context 'with value-level proc' do
      let(:config) do
        {
          'default' => {
            'second' => 'false'
          },
          'other' => {
            'something' => ->(context, _) { context }
          }
        }
      end
      let(:expected_context) { CernerSplunk::ConfHelpers::ConfContext.new(conf_path, 'other', 'something') }
      let(:expected_config) do
        {
          'default' => {
            'second' => 'false'
          },
          'other' => {
            'something' => expected_context
          }
        }
      end

      it { is_expected.to eq(expected_config) }
    end
  end

  describe 'stringify_config' do
    let(:config) do
      {
        one: {
          'a' => 'string',
          b: 1000,
          c: {
            deep: :deep
          },
          d: nil
        },
        'two' => {
          even: 'more'
        }
      }
    end
    let(:expected_config) do
      {
        'one' => {
          'a' => 'string',
          'b' => '1000',
          'c' => '{:deep=>:deep}',
          'd' => nil
        },
        'two' => {
          'even' => 'more'
        }
      }
    end

    it 'should convert section and property keys into strings' do
      expect(CernerSplunk::ConfHelpers.stringify_config(config)).to eq(expected_config)
    end
  end

  describe 'read_config' do
    let(:expected_config) do
      {
        'default' => {
          'outside' => 'true',
          'inside' => 'true'
        },
        'spacey! bit?' => {
          'some thing' => 'is here',
          'another' => 'one here'
        }
      }
    end

    it 'should read and parse the config from a given pathname' do
      expect(Pathname).to receive(:new).with(conf_path).and_return(Pathname.new('spec/reference/read_test.conf'))
      expect(CernerSplunk::ConfHelpers.read_config(conf_path)).to eq(expected_config)
    end

    context 'when the path does not exist' do
      let(:conf_file) { double('Pathname.new(conf_path)') }

      it 'should return an empty hash' do
        expect(Pathname).to receive(:new).with(conf_path).once.and_return(conf_file)

        expect(conf_file).to receive(:exist?).and_return(false)
        expect(CernerSplunk::ConfHelpers.read_config(conf_path)).to eq({})
      end
    end
  end

  describe 'parse_config' do
    let(:expected_config) do
      {
        'default' => {
          'outside' => 'true',
          'inside' => 'true'
        },
        'spacey! bit?' => {
          'some thing' => 'is here',
          'another' => 'one here'
        }
      }
    end

    it 'should return the config in a hash' do
      expect(CernerSplunk::ConfHelpers.parse_config(IO.read('spec/reference/read_test.conf'))).to eq(expected_config)
    end
  end

  describe 'merge_config' do
    subject { CernerSplunk::ConfHelpers.merge_config(existing_config, config) }
    let(:config) do
      {
        'default' => {
          'first' => nil
        },
        'another' => {
          'something' => 'there'
        }
      }
    end
    let(:expected_config) do
      {
        'default' => {
          'first' => 'false',
          'second' => 'true'
        },
        'another' => {
          'something' => 'there'
        },
        'other' => {
          'something' => 'here'
        }
      }
    end

    it { is_expected.to eq expected_config }

    context 'when current_config is empty' do
      it 'should return only the given config' do
        expect(CernerSplunk::ConfHelpers.merge_config({}, config)).to eq config
      end
    end
  end

  describe 'filter_config' do
    subject { CernerSplunk::ConfHelpers.filter_config(config) }
    let(:config) do
      {
        'default' => {
          'first' => ''
        },
        'other' => nil,
        'another' => {
          'something' => 'there',
          'else' => nil
        }
      }
    end

    let(:expected_config) do
      {
        'default' => {
          'first' => ''
        },
        'another' => {
          'something' => 'there'
        }
      }
    end

    it { is_expected.to eq expected_config }
  end
end
