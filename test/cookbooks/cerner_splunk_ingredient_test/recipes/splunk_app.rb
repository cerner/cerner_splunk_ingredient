configs_proc = proc do
  splunk_conf 'testing.conf' do
    config(
      debug: {
        banana: 'yellow'
      }
    )
  end
end

files_proc = proc do |app_path|
  file Pathname.new(app_path).join('plain_file.txt').to_s do
    owner 'splunk'
    content 'A secret to everybody'
  end
end

meta_config = {
  views: {
    access: { read: '*', write: %w(admin power) }
  },
  'views/index_check' => {
    access: { read: 'admin', write: 'admin' }
  }
}

splunk_app_custom 'test_app' do
  configs configs_proc
  files files_proc
  metadata meta_config
end

splunk_app_package 'pkg_app' do
  source_url 'file:///tmp/kitchen/data/pkg-app.spl'
  configs configs_proc
  files files_proc
  metadata meta_config
end
