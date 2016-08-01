splunk_conf 'system/indexes.conf' do
  config(
    my_index: {
      homePath: '$SPLUNK_DB/my_index/db',
      coldPath: '$SPLUNK_DB/my_index/colddb',
      thawedPath: '$SPLUNK_DB/my_index/thaweddb'
    },
    your_index: {
      homePath: '$SPLUNK_DB/your_index/db',
      coldPath: '$SPLUNK_DB/your_index/colddb',
      thawedPath: '$SPLUNK_DB/your_index/thaweddb'
    }
  )
  reset true
end
