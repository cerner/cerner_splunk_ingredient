# frozen_string_literal: true

windows = os.windows?
splunk_path = windows ? 'c:\Program Files\Splunk' : '/opt/splunk'
splunk_command = windows ? "& \"#{splunk_path}\\bin\\splunk.exe\"" : "#{splunk_path}/bin/splunk"

describe package(windows ? 'Splunk Enterprise' : 'splunk') do
  it { is_expected.to be_installed }
  its('version') { is_expected.to match(/6\.3\.4(\.0)?(-cae2458f4aef)?/) }
end

describe service(windows ? 'splunkd' : 'splunk') do
  it { is_expected.to be_installed }
  it { is_expected.to be_running }
end

describe command("#{splunk_command} status") do
  its('exit_status') { is_expected.to eq 0 }
end

describe file(splunk_path) do
  it { is_expected.to be_directory }
  its('owner') { is_expected.to match(/splunk$/) } unless windows
end

describe file((Pathname.new(splunk_path) + 'etc/system/local/indexes.conf').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunk$/) } unless windows
  its('content') { is_expected.to match(/\[test_index\]/) }
  its('content') { is_expected.to match %r{homePath = \$SPLUNK_DB/test_index/db} }
  its('content') { is_expected.to match %r{coldPath = \$SPLUNK_DB/test_index/colddb} }
  its('content') { is_expected.to match %r{thawedPath = \$SPLUNK_DB/test_index/thaweddb} }
end

test_app_path = Pathname.new(splunk_path) + 'etc/apps/test_app'

describe file(test_app_path.to_s) do
  it { is_expected.to be_directory }
  its('owner') { is_expected.to match(/splunk$/) } unless windows
end

describe file((test_app_path + 'default/testing.conf').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunk$/) } unless windows
  its('content') { is_expected.to match(/\[debug\]/) }
  its('content') { is_expected.to match(/banana = green/) }
end

describe file((test_app_path + 'default/app.conf').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunk$/) } unless windows
  its('content') { is_expected.to match(/\[launcher\]/) }
  its('content') { is_expected.to match(/version = 1.0.0/) }
end

describe file((test_app_path + 'plain_file.txt').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunk$/) } unless windows
  its('content') { is_expected.to match(/A secret to everybody/) }
end

describe file((test_app_path + 'metadata/default.meta').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunk$/) } unless windows
  its('content') { is_expected.to match(/\[views\]/) }
  its('content') { is_expected.to match(/access = read : \[ \* \], write : \[ admin, power \]/) }
  its('content') { is_expected.to match(%r{\[views/index_check\]}) }
  its('content') { is_expected.to match(/access = read : \[ admin \], write : \[ admin \]/) }
end

unless windows
  describe file('/etc/init.d/splunk') do
    it { is_expected.to be_file }
    its('content') { is_expected.to match(/RETVAL=0\s+ulimit -n 4000/m) }
  end

  describe file("#{splunk_path}/restart_on_chef_client") do
    it { is_expected.not_to exist }
  end

  describe command('cat /proc/$(pgrep splunkd | sed -n 1p)/limits') do
    its('stdout') { is_expected.to match(/^Max open files \s+ \w+ \s+ 4000 \s+ files\s*$/m) }
  end

  describe command('ps --no-headers -C splunkd -o %U | sed -n 1p') do
    its('stdout') { is_expected.to match(/splunk/) }
  end
end
