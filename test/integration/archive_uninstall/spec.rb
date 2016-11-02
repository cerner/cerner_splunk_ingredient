windows = os.windows?

control 'basic_uninstall' do
  impact 0.4
  title 'Uninstall Splunk'
  tag 'splunk_install'

  describe service(windows ? 'splunkd' : 'splunk') do
    it { is_expected.not_to be_running }
    it { is_expected.not_to be_enabled }
    it { is_expected.not_to be_installed } if windows
  end

  unless windows
    describe command('ps -eo comm= | grep splunkd') do
      its('exit_status') { is_expected.to eq 1 }
    end

    describe file('/etc/init.d/splunk') do
      it { is_expected.not_to exist }
    end
  end
end
