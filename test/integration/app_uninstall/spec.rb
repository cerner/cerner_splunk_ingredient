windows = os.windows?
splunk_path = windows ? 'c:\Program Files\Splunk' : '/opt/splunk'
app_path = Pathname.new(splunk_path).join('etc/apps/test_app').to_s

describe file(app_path) do
  it { is_expected.not_to exist }
end
