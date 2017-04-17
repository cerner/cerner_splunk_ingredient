# frozen_string_literal: true

app_url = platform_family?('windows') ? 'file:///C:/Users/Vagrant/AppData/Local/Temp/kitchen/data/pkg-app.spl' : 'file:///tmp/kitchen/data/pkg-app.spl'

splunk_install 'universal_forwarder' do
  user 'splunkforwarder' unless platform_family? 'windows'
  version '6.3.4'
  build 'cae2458f4aef'
end

splunk_conf 'system/server.conf' do
  config(
    general: {
      serverName: 'test-forwarder'
    }
  )
end

splunk_service 'universal_forwarder' do
  ulimit 3000
end

splunk_app_package 'test_app' do
  source_url app_url
  version '1.2.0'
  configs(proc do
    splunk_conf 'testing.conf' do
      config(debug: { banana: 'yellow' })
    end
  end)
  metadata(
    views: { access: { read: '*', write: %w[admin power] } },
    'views/index_check' => { access: { read: 'admin', write: 'admin' } }
  )
end
