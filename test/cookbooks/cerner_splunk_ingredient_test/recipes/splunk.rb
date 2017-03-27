# frozen_string_literal: true

splunk_install 'splunk' do
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

splunk_app_custom 'test_app' do
  version '1.0.0'
  configs(proc do
    splunk_conf 'testing.conf' do
      config(debug: { banana: 'green' })
    end
    splunk_conf 'app.conf' do
      config(launcher: { version: '1.0.0' })
    end
  end)
  files(proc do |app_path|
    file((Pathname.new(app_path) + 'plain_file.txt').to_s) do
      owner 'splunk' unless platform_family? 'windows'
      content 'A secret to everybody'
    end
  end)
  metadata(
    views: { access: { read: '*', write: %w(admin power) } },
    'views/index_check' => { access: { read: 'admin', write: 'admin' } }
  )
end
