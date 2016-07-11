windows = os.windows?

control 'forwarder_uninstall' do
  impact 0.4
  title 'Uninstall Universal Forwarder'
  tag 'splunk_install'

  describe package(windows ? 'UniversalForwarder' : 'splunkforwarder') do
    it { is_expected.not_to be_installed }
  end

  describe command('ps -eo comm= | grep splunkd') do
    its('exit_status') { is_expected.to eq 1 }
  end

  describe service(windows ? 'splunkforwarder' : 'splunk') do
    it { is_expected.not_to be_running }
    it { is_expected.not_to be_enabled }
    it { is_expected.not_to be_installed } if windows
  end

  describe file('/etc/init.d/splunk') do
    it { is_expected.not_to exist }
  end unless windows
end
