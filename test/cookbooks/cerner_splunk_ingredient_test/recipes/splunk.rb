splunk_install 'splunk' do
  user 'splunk'
  version '6.3.4'
  build 'cae2458f4aef'
  base_url 'http://download.splunk.com/products'
end

splunk_conf 'system/indexes.conf' do
  config(
    test_index: {
      homePath: '$SPLUNK_DB/test_index/db',
      coldPath: '$SPLUNK_DB/test_index/colddb',
      thawedPath: '$SPLUNK_DB/test_index/thaweddb'
    }
  )
end

splunk_service 'splunk' do
  ulimit 4000
end
