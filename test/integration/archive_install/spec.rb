# frozen_string_literal: true
windows = os.windows?
splunk_path = windows ? 'c:\splunk' : '/etc/splunk'
splunk_command = windows ? "& \"#{splunk_path}\\bin\\splunk.exe\"" : "#{splunk_path}/bin/splunk"

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

describe file(Pathname.new(splunk_path).join('etc/system/local/indexes.conf').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunk$/) } unless windows
  its('content') { is_expected.to match(/\[test_index\]/) }
  its('content') { is_expected.to match %r{homePath = \$SPLUNK_DB/test_index/db} }
  its('content') { is_expected.to match %r{coldPath = \$SPLUNK_DB/test_index/colddb} }
  its('content') { is_expected.to match %r{thawedPath = \$SPLUNK_DB/test_index/thaweddb} }
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
end
