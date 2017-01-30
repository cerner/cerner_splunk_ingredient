splunk_app_custom 'test_app' do
  configs(proc do
    splunk_conf 'testing.conf' do
      config(
        debug: {
          banana: 'yellow'
        }
      )
    end
  end)

  files(proc do |app_path|
    file Pathname.new(app_path).join('plain_file.txt').to_s do
      owner 'splunk'
      content 'A secret to everybody'
    end
  end)

  metadata(
    views: {
      access: { read: '*', write: %w(admin power) }
    },
    'views/index_check' => {
      access: { read: 'admin', write: 'admin' }
    }
  )
end
