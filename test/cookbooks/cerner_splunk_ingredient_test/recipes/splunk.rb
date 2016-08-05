splunk_install 'splunk' do
  user 'splunk'
  version '6.3.4'
  build 'cae2458f4aef'
  base_url 'http://download.splunk.com/products'
end

splunk_service 'splunk' do
  ulimit 4000
end
