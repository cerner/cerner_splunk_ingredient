# frozen_string_literal: true

splunk_install 'splunk' do
  action :uninstall
  notifies :clear, 'splunk_restart[splunk]', :immediately
end
