require_relative '../spec_helper'

describe 'ConfHelpers' do
  include CernerSplunk::ConfHelpers

  let(:conf_path) { '/opt/splunk/etc/system/local/test.conf' }

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
      expect(stringify_config(config)).to eq(expected_config)
    end
  end

  describe 'read_config' do
    let(:expected_config) do
      {
        'default' => {
          'outside' => 'true',
          'inside' => 'true'
        },
        'other' => {
          'something' => 'here'
        }
      }
    end
    let(:conf_file) { double('Pathname.new(conf_path)') }

    it 'should return the config in a hash' do
      expect(Pathname).to receive(:new).with(conf_path).twice.and_return(conf_file)
      expect(conf_file).to receive(:exist?).and_return(true)
      expect(conf_file).to receive(:readlines).and_return(IO.readlines('spec/reference/read_test.conf'))

      expect(read_config(conf_path)).to eq(expected_config)
    end

    context 'when the path does not exist' do
      it 'should return an empty hash' do
        expect(Pathname).to receive(:new).with(conf_path).once.and_return(conf_file)

        expect(conf_file).to receive(:exist?).and_return(false)
        expect(read_config(conf_path)).to eq({})
      end
    end
  end

  describe 'apply_config' do
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
    let(:io_stream) { StringIO.new }
    let(:conf_file) { double('Pathname.new(conf_path)') }
    let(:expected_conf_file) { IO.read('spec/reference/write_test.conf') }

    before do
      expect(Pathname).to receive(:new).with(conf_path).and_return(conf_file)

      expect(conf_file).to receive(:open) do |mode, &blk|
        io_stream.tap(&blk) if mode == 'w'
      end.twice
    end

    it 'should write the config with new and old properties' do
      apply_config(conf_path, config, existing_config)
      expect(io_stream.string).to eq expected_conf_file
    end

    context 'when current_config is falsey' do
      before do
        expect(self).to receive(:read_config).with(conf_path).and_return(existing_config)
      end

      it 'should read the existing config from the file' do
        apply_config(conf_path, config, false)
        expect(io_stream.string).to eq expected_conf_file
      end
    end

    context 'when current_config is empty' do
      let(:expected_conf_file) { IO.read('spec/reference/write_test_overwrite.conf') }

      it 'should write only the given config to the file' do
        apply_config(conf_path, config, {})
        expect(io_stream.string).to eq expected_conf_file
      end
    end
  end

  describe 'resolve_types' do
    let(:config) do
      {
        'one' => {
          'a' => 'true',
          'b' => '1000',
          'c' => '50.99',
          'd' => 'false'
        },
        'two' => {
          'even' => 'more'
        }
      }
    end
    let(:expected_config) do
      {
        'one' => {
          'a' => true,
          'b' => 1000,
          'c' => 50.99,
          'd' => false
        },
        'two' => {
          'even' => 'more'
        }
      }
    end

    it 'should resolve types for the given config' do
      expect(resolve_types(config)).to eq(expected_config)
    end
  end
end
