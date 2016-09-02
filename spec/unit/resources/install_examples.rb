shared_examples 'should install' do |platform, expected_url|
  it { is_expected.to create_remote_file(package_path).with(source: expected_url) }

  case platform
  when 'redhat' then it { is_expected.to install_rpm_package(package_name).with(source: package_path) }
  when 'ubuntu' then it { is_expected.to install_dpkg_package(package_name).with(source: package_path) }
  when 'windows' then it { is_expected.to install_windows_package(package_name).with(options: windows_opts) }
  else it { is_expected.to extract_local_tar_extract(package_path).with(target_dir: install_dir) }
  end
end

shared_examples 'standard install' do |platform, package, expected_url|
  chef_context "with the '#{package}' package" do
    let(:test_params) { { name: package.to_s, build: 'cae2458f4aef', version: '6.3.4' } }
    let(:package_path) { "./test/unit/.cache/#{filename_from_url(expected_url)}" }

    include_examples 'should install', platform, expected_url

    chef_context 'when already installed' do
      let(:install) do
        {
          name: package.to_s,
          package: package,
          version: '6.3.4',
          build: 'cae2458f4aef',
          x64: true
        }
      end
      let(:mock_run_state) do
        {
          'splunk_ingredient' => {
            'installations' => {
              install_dir => install
            },
            'current_installation' => install
          }
        }
      end

      chef_context 'with a different version' do
        let(:install) do
          {
            name: package.to_s,
            package: package,
            version: '5.5.5',
            build: 'a1b2c3d4e5f6',
            x64: true
          }
        end

        include_examples 'should install', platform, expected_url
      end

      chef_context 'with the same version' do
        it { is_expected.not_to create_remote_file(package_path).with(source: expected_url) }

        case platform
        when 'redhat' then it { is_expected.not_to install_rpm_package(package_name) }
        when 'ubuntu' then it { is_expected.not_to install_dpkg_package(package_name) }
        when 'windows' then it { is_expected.not_to install_windows_package(package_name) }
        else it { is_expected.not_to extract_local_tar_extract(package_path) }
        end
      end
    end
  end
end

shared_examples 'standard uninstall' do |platform, package|
  chef_context "with the '#{package}' package" do
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

    case platform
    when 'redhat' then it { is_expected.to remove_rpm_package(package_name) }
    when 'ubuntu' then it { is_expected.to purge_dpkg_package(package_name) }
    when 'windows' then it { is_expected.to remove_windows_package(package_name) }
    else it { is_expected.to delete_directory(install_dir).with(recursive: true) }
    end

    it { is_expected.to stop_splunk_service(package) }
    it { is_expected.to run_execute("#{command_prefix} disable boot-start").with(cwd: "#{install_dir}/bin") }

    it 'should remove run state' do
      expect(run_state).not_to include(:current_installation)
      expect(run_state['installations']).not_to include(install_dir)
    end
  end
end
