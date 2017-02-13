node.default['splunk']['install_dir'] = node['os'] == 'windows' ? 'c:\splunk' : '/etc/splunk'

splunk_install_archive 'splunk' do
  install_dir node['splunk']['install_dir']
  version '6.3.4'
  build 'cae2458f4aef'
  base_url 'http://download.splunk.com/products'
end

splunk_conf 'system/indexes.conf' do
  install_dir node['splunk']['install_dir']
  config(
    test_index: {
      homePath: '$SPLUNK_DB/test_index/db',
      coldPath: '$SPLUNK_DB/test_index/colddb',
      thawedPath: '$SPLUNK_DB/test_index/thaweddb'
    }
  )
end

splunk_service 'splunk' do
  install_dir node['splunk']['install_dir']
  ulimit 4000
end
