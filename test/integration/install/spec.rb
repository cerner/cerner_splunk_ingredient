windows = os.windows?

control 'basic_install' do
  impact 0.4
  title 'Install Splunk'
  tag 'splunk_install'

  describe package(windows ? 'Splunk Enterprise' : 'splunk') do
    it { is_expected.to be_installed }
    its('version') { is_expected.to match(/6\.3\.4(\.0)?(-cae2458f4aef)?/) }
  end

  describe command('ps -eo comm= | grep splunk') do
    its('exit_status') { is_expected.to eq 1 }
  end
end

control 'forwarder_install' do
  impact 0.4
  title 'Install Universal Forwarder'
  tag 'splunk_install'

  describe package(windows ? 'UniversalForwarder' : 'splunkforwarder') do
    it { is_expected.to be_installed }
    its('version') { is_expected.to match(/6\.3\.4(\.0)?(-cae2458f4aef)?/) }
  end

  describe command('ps -eo comm= | grep splunk') do
    its('exit_status') { is_expected.to eq 1 }
  end
end
