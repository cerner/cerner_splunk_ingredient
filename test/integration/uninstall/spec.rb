control 'basic_uninstall' do
  impact 0.4
  title 'Uninstall Splunk'
  tag 'splunk_install'

  describe package(os.windows? ? 'Splunk Enterprise' : 'splunk') do
    it { is_expected.not_to be_installed }
  end

  describe command('ps -eo comm= | grep splunk') do
    its('exit_status') { is_expected.to eq 1 }
  end
end

control 'forwarder_uninstall' do
  impact 0.4
  title 'Uninstall Universal Forwarder'
  tag 'splunk_install'

  describe package(os.windows? ? 'UniversalForwarder' : 'splunkforwarder') do
    it { is_expected.not_to be_installed }
  end

  describe command('ps -eo comm= | grep splunk') do
    its('exit_status') { is_expected.to eq 1 }
  end
end
