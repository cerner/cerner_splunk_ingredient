# frozen_string_literal: true
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
