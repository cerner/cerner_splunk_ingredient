require_relative '../spec_helper'

describe 'PathHelpers' do
  include CernerSplunk::PathHelpers

  describe 'filename_from_url' do
    let(:expected_filename) { 'my_filename.tgz' }
    it 'should return the filename in a URL' do
      url = 'https://cool.website.internet/place/my_filename.tgz'
      expect(CernerSplunk::PathHelpers.filename_from_url(url)).to eq(expected_filename)
    end
  end
end
