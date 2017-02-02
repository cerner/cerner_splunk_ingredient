windows = os.windows?
splunk_path = windows ? 'c:\Program Files\Splunk' : '/opt/splunk'

%w(test_app pkg_app).each do |app_name|
  describe file(Pathname.new(splunk_path).join('etc/apps').join(app_name).to_s) do
    it { is_expected.not_to exist }
  end
end
