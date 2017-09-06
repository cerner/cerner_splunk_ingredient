# frozen_string_literal: true

windows = os.windows?
splunk_path = windows ? 'c:\Program Files\SplunkUniversalForwarder' : '/opt/splunkforwarder'
splunk_command = windows ? "& \"#{splunk_path}\\bin\\splunk.exe\"" : "#{splunk_path}/bin/splunk"

describe package(windows ? 'UniversalForwarder' : 'splunkforwarder') do
  it { is_expected.to be_installed }
  its('version') { is_expected.to match(/6\.3\.4(\.0)?(-cae2458f4aef)?/) }
end

describe service(windows ? 'splunkforwarder' : 'splunk') do
  it { is_expected.to be_installed }
  it { is_expected.to be_running }
end

describe command("#{splunk_command} status") do
  its('exit_status') { is_expected.to eq 0 }
end

describe file(splunk_path) do
  it { is_expected.to be_directory }
  its('owner') { is_expected.to match(/splunkforwarder$/) } unless windows
end

describe file((Pathname.new(splunk_path) + 'etc/system/local/server.conf').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunkforwarder$/) } unless windows
  its('content') { is_expected.to match '[general]' }
  its('content') { is_expected.to match 'serverName = test-forwarder' }
  its('content') { is_expected.to match '[sslConfig]' }
  its('content') { is_expected.to match(/sslKeysfilePassword = .+/) }
end

unless windows
  describe file('/etc/init.d/splunk') do
    it { is_expected.to be_file }
    its('content') { is_expected.to match(/RETVAL=0\s+ulimit -n 3000/m) }
  end

  describe file("#{splunk_path}/restart_on_chef_client") do
    it { is_expected.not_to exist }
  end

  describe command('cat /proc/$(pgrep splunkd | sed -n 1p)/limits') do
    its('stdout') { is_expected.to match(/^Max open files \s+ \w+ \s+ 3000 \s+ files\s*$/m) }
  end
end

test_app_path = Pathname.new(splunk_path) + 'etc/apps/test_app'

describe file(test_app_path.to_s) do
  it { is_expected.to be_directory }
  its('owner') { is_expected.to match(/splunkforwarder$/) } unless windows
end

describe file((test_app_path + 'default/testing.conf').to_s) do
  it { is_expected.not_to be_file }
end

describe file((test_app_path + 'local/testing.conf').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunkforwarder$/) } unless windows

  its('content') { is_expected.to match(/\[debug\]/) }
  its('content') { is_expected.to match(/banana = yellow/) }
end

describe file((test_app_path + 'default/app.conf').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunkforwarder$/) } unless windows

  its('content') { is_expected.to match(/\[launcher\]/) }
  its('content') { is_expected.to match(/version = 1\.2\.0/) }
  its('content') { is_expected.to match(/\[package\]/) }
  its('content') { is_expected.to match(/check_for_updates = 0/) }
  its('content') { is_expected.to match(/\[install\]/) }
  its('content') { is_expected.to match(/is_configured = 0/) }
  its('content') { is_expected.to match(/\[ui\]/) }
  its('content') { is_expected.to match(/is_visible = 1/) }
  its('content') { is_expected.to match(/label = Test App/) }
end

describe file((test_app_path + 'metadata/default.meta').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunkforwarder$/) } unless windows

  its('content') { is_expected.to match(/\[\]/) }
  its('content') { is_expected.to match(/access = read : \[ \* \]/) }

  its('content') { is_expected.not_to match(/\[views\]/) }
  its('content') { is_expected.not_to match(/access = read : \[ \* \], write : \[ admin, power \]/) }
  its('content') { is_expected.not_to match(%r{\[views/index_check\]}) }
  its('content') { is_expected.not_to match(/access = read : \[ admin \], write : \[ admin \]/) }
end

describe file((test_app_path + 'metadata/local.meta').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunkforwarder$/) } unless windows

  its('content') { is_expected.to match(/\[views\]/) }
  its('content') { is_expected.to match(/access = read : \[ \* \], write : \[ admin, power \]/) }
  its('content') { is_expected.to match(%r{\[views/index_check\]}) }
  its('content') { is_expected.to match(/access = read : \[ admin \], write : \[ admin \]/) }
end
