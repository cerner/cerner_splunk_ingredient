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
    subject { CernerSplunk::ConfHelpers.evaluate_config(existing_config, config) }

    context 'with top-level proc' do
      let(:config) do
        ->(conf) { conf.map { |section, props| [section.upcase, props] }.to_h }
      end
      let(:expected_config) do
        {
          'DEFAULT' => {
            'first' => 'true',
            'second' => 'true'
          },
          'OTHER' => {
            'something' => 'here'
          }
        }
      end

      it { is_expected.to eq(expected_config) }
    end

    context 'with stanza-level proc' do
      let(:config) do
        {
          'default' => {
            'second' => 'false'
          },
          'other' => ->(section, props) { [section.upcase, props] }
        }
      end
      let(:expected_config) do
        {
          'default' => {
            'second' => 'false'
          },
          'OTHER' => {
            'something' => 'here'
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
          }
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
          'c' => '{:deep=>:deep}'
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

    it 'should call parse_config' do
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
    let(:config) do
      {
        'default' => {
          'first' => 'false'
        },
        'another' => {
          'something' => 'there'
        }
      }
    end
    let(:expected_config) { IO.read('spec/reference/write_test.conf') }

    it 'should write the config with new and old properties' do
      expect(CernerSplunk::ConfHelpers.merge_config(existing_config, config)).to eq expected_config
    end

    context 'when current_config is empty' do
      let(:expected_config) { IO.read('spec/reference/write_test_overwrite.conf') }

      it 'should write only the given config to the file' do
        expect(CernerSplunk::ConfHelpers.merge_config({}, config)).to eq expected_config
      end
    end
  end
end
