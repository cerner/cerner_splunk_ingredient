shared_examples 'should install' do |platform, expected_url|
  it 'should install' do
    expect(run_state['current_installation']).to eq(
      name: package.to_s,
      package: package,
      version: '6.3.4',
      build: 'cae2458f4aef',
      x64: true
    )

    expect(chef_run).to create_remote_file(package_path).with(source: expected_url)

    case platform
    when 'redhat' then expect(chef_run).to install_rpm_package(package_name).with(source: package_path)
    when 'ubuntu' then expect(chef_run).to install_dpkg_package(package_name).with(source: package_path)
    when 'windows' then expect(chef_run).to install_windows_package(package_name).with(options: windows_opts)
    else expect(chef_run).to extract_local_tar_extract(package_path).with(target_dir: install_dir)
    end
  end
end

shared_examples 'should not install' do |platform, expected_url|
  it 'should not install' do
    expect(chef_run).not_to create_remote_file(package_path).with(source: expected_url)

    case platform
    when 'redhat' then expect(chef_run).not_to install_rpm_package(package_name)
    when 'ubuntu' then expect(chef_run).not_to install_dpkg_package(package_name)
    when 'windows' then expect(chef_run).not_to install_windows_package(package_name)
    else expect(chef_run).not_to extract_local_tar_extract(package_path)
    end
  end
end

shared_examples 'should uninstall' do |platform|
  it 'should uninstall' do
    case platform
    when 'redhat' then expect(chef_run).to remove_rpm_package(package_name)
    when 'ubuntu' then expect(chef_run).to purge_dpkg_package(package_name)
    when 'windows' then expect(chef_run).to remove_windows_package(package_name)
    else expect(chef_run).to delete_directory(install_dir).with(recursive: true)
    end

    expect(run_state).not_to include(:current_installation)
    expect(run_state['installations']).not_to include(install_dir)
  end
end

shared_context 'test setup' do |platform, version, package|
  let(:package_name) { package_names[package][runner_params[:platform] == 'windows' ? :windows : :linux] }
  let(:install_dir) { default_install_dirs[package][runner_params[:platform] == 'windows' ? :windows : :linux] }
  let(:runner_params) { { platform: platform, version: version } }
end

shared_examples 'standard install' do |platform, version, package, expected_url|
  context "with the '#{package}' package" do
    include_context 'test setup', platform, version, package
    let(:package) { package }
    let(:test_params) { { name: package.to_s, build: 'cae2458f4aef', version: '6.3.4' } }
    let(:package_path) { "./test/unit/.cache/#{filename_from_url(expected_url)}" }

    include_examples 'should install', platform, expected_url

    context 'when already installed' do
      context 'with a different version' do
        before do
          version_double = double('splunk.version double')
          expect(version_double).to receive(:exist?).and_return(true)
          expect(version_double).to receive(:read)
            .and_return("VERSION=5.5.5\nBUILD=a1b2c3d4e5f6")
          expect_any_instance_of(Chef::Resource).to receive(:version_pathname).and_return(version_double)
        end

        include_examples 'should install', platform, expected_url
      end

      context 'with the same version' do
        before do
          version_double = double('splunk.version double')
          expect(version_double).to receive(:exist?).and_return(true)
          expect(version_double).to receive(:read)
            .and_return("VERSION=6.3.4\nBUILD=cae2458f4aef")
          expect_any_instance_of(Chef::Resource).to receive(:version_pathname).and_return(version_double)
        end

        include_examples 'should not install', platform, expected_url
      end
    end
  end
end

shared_examples 'standard uninstall' do |platform, version, package|
  context "with the '#{package}' package" do
    include_context 'test setup', platform, version, package
    let(:test_params) { { name: package.to_s, action: :uninstall } }
    let(:mock_run_state) do
      install = {
        name: package.to_s,
        package: package,
        version: '6.3.4',
        build: 'cae2458f4aef',
        x64: true
      }
      {
        'splunk_ingredient' => {
          'installations' => {
            install_dir => install
          },
          'current_installation' => install
        }
      }
    end

    include_examples 'should uninstall', platform
  end
end
