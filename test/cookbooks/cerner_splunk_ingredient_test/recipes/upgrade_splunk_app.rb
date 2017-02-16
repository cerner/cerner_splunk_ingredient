# frozen_string_literal: true
app_url = platform_family?('windows') ? 'file:///C:/Users/Vagrant/AppData/Local/Temp/kitchen/data/pkg-app.spl' : 'file:///tmp/kitchen/data/pkg-app.spl'

splunk_app_package 'test_app' do
  source_url app_url
  version '1.2.0'
  configs(proc do
    splunk_conf 'testing.conf' do
      config(debug: { banana: 'yellow' })
    end
  end)
  metadata(
    views: { access: { read: '*', write: %w(admin power) } },
    'views/index_check' => { access: { read: 'admin', write: 'admin' } }
  )
end
