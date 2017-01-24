windows = os.windows?
splunk_path = windows ? 'c:\Program Files\Splunk' : '/opt/splunk'
app_path = Pathname.new(splunk_path).join('etc/apps/test_app').to_s

describe file(app_path) do
  it { is_expected.to be_directory }
  it { is_expected.to be_owned_by 'splunk' } unless windows
end

describe file(Pathname.new(app_path).join('default/testing.conf').to_s) do
  it { is_expected.to be_file }
  it { is_expected.to be_owned_by 'splunk' } unless windows
  its('content') { is_expected.to match(/\[debug\]/) }
  its('content') { is_expected.to match(/banana = yellow/) }
end

describe file(Pathname.new(app_path).join('plain_file.txt').to_s) do
  it { is_expected.to be_file }
  it { is_expected.to be_owned_by 'splunk' } unless windows
  its('content') { is_expected.to match(/A secret to everybody/) }
end

describe file(Pathname.new(app_path).join('metadata/default.meta').to_s) do
  it { is_expected.to be_file }
  it { is_expected.to be_owned_by 'splunk' } unless windows
  its('content') { is_expected.to match(/\[views\]/) }
  its('content') { is_expected.to match(/access = read : \[ * \], write : \[ admin, power \]/) }
  its('content') { is_expected.to match(%r{\[views/index_check\]}) }
  its('content') { is_expected.to match(/access = read : \[ admin \], write : \[ admin \]/) }
end
