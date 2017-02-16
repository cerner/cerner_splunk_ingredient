# frozen_string_literal: true
splunk_install_archive 'splunk' do
  install_dir node['splunk']['install_dir']
  action :uninstall
end
