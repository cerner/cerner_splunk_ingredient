control 'helpers' do
  impact 0.1
  title 'Test helpers and their accessibility from recipes'
  tag 'helpers'

  describe file('/opt/my_config.conf') do
    it { is_expected.to be_file }
    its('content') { is_expected.to match(/\[first\]/) }
    its('content') { is_expected.to match(/blue = 0000FF/) }
    its('content') { is_expected.to match(/green = 00FF00/) }
    its('content') { is_expected.to match(/yes = true/) }
  end
end
