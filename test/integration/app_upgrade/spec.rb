# frozen_string_literal: true
windows = os.windows?
splunk_path = windows ? 'c:\Program Files\Splunk' : '/opt/splunk'

test_app_path = Pathname.new(splunk_path).join('etc/apps/test_app')

describe file(test_app_path.to_s) do
  it { is_expected.to be_directory }
  its('owner') { is_expected.to match(/splunk$/) } unless windows
end

describe file(test_app_path.join('default/testing.conf').to_s) do
  it { is_expected.not_to be_file }
end

describe file(test_app_path.join('local/testing.conf').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunk$/) } unless windows

  its('content') { is_expected.to match(/\[debug\]/) }
  its('content') { is_expected.to match(/banana = yellow/) }
end

describe file(test_app_path.join('default/app.conf').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunk$/) } unless windows

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

describe file(test_app_path.join('plain_file.txt').to_s) do
  it { is_expected.not_to be_file }
end

describe file(test_app_path.join('metadata/default.meta').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunk$/) } unless windows

  its('content') { is_expected.to match(/\[\]/) }
  its('content') { is_expected.to match(/access = read : \[ \* \]/) }

  its('content') { is_expected.not_to match(/\[views\]/) }
  its('content') { is_expected.not_to match(/access = read : \[ \* \], write : \[ admin, power \]/) }
  its('content') { is_expected.not_to match(%r{\[views/index_check\]}) }
  its('content') { is_expected.not_to match(/access = read : \[ admin \], write : \[ admin \]/) }
end

describe file(test_app_path.join('metadata/local.meta').to_s) do
  it { is_expected.to be_file }
  its('owner') { is_expected.to match(/splunk$/) } unless windows

  its('content') { is_expected.to match(/\[views\]/) }
  its('content') { is_expected.to match(/access = read : \[ \* \], write : \[ admin, power \]/) }
  its('content') { is_expected.to match(%r{\[views/index_check\]}) }
  its('content') { is_expected.to match(/access = read : \[ admin \], write : \[ admin \]/) }
end
