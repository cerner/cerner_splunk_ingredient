# frozen_string_literal: true
require 'rspec/expectations'
require 'chefspec'
require 'chefspec/berkshelf'
require 'chef/application'
%w(path platform resource restart service conf file provider).each { |helper| require_relative "../../libraries/#{helper}_helpers" }

RSpec.configure do |config|
  config.extend(ChefSpec::Cacher)
  config.color = true
  config.formatter = 'documentation'
  config.order = 'rand'

  # Specify the path for Chef Solo file cache path (default: nil)
  config.file_cache_path = './test/unit/.cache'

  # Specify the Chef log_level (default: :warn)
  config.log_level = :warn
end

def platform_package_urls
  {
    linux: {
      archive: {
        splunk: 'https://download.splunk.com/products/splunk/releases/6.3.4/linux/splunk-6.3.4-cae2458f4aef-Linux-x86_64.tgz',
        universal_forwarder: 'https://download.splunk.com/products/universalforwarder/releases/6.3.4/linux/splunkforwarder-6.3.4-cae2458f4aef-Linux-x86_64.tgz'
      },
      redhat: {
        splunk: 'https://download.splunk.com/products/splunk/releases/6.3.4/linux/splunk-6.3.4-cae2458f4aef-linux-2.6-x86_64.rpm',
        universal_forwarder: 'https://download.splunk.com/products/universalforwarder/releases/6.3.4/linux/splunkforwarder-6.3.4-cae2458f4aef-linux-2.6-x86_64.rpm'
      },
      debian: {
        splunk: 'https://download.splunk.com/products/splunk/releases/6.3.4/linux/splunk-6.3.4-cae2458f4aef-linux-2.6-amd64.deb',
        universal_forwarder: 'https://download.splunk.com/products/universalforwarder/releases/6.3.4/linux/splunkforwarder-6.3.4-cae2458f4aef-linux-2.6-amd64.deb'
      }
    },
    windows: {
      archive: {
        splunk: 'https://download.splunk.com/products/splunk/releases/6.3.4/windows/splunk-6.3.4-cae2458f4aef-windows-64.zip',
        universal_forwarder: 'https://download.splunk.com/products/universalforwarder/releases/6.3.4/windows/splunkforwarder-6.3.4-cae2458f4aef-windows-64.zip'
      },
      msi: {
        splunk: 'https://download.splunk.com/products/splunk/releases/6.3.4/windows/splunk-6.3.4-cae2458f4aef-x64-release.msi',
        universal_forwarder: 'https://download.splunk.com/products/universalforwarder/releases/6.3.4/windows/splunkforwarder-6.3.4-cae2458f4aef-x64-release.msi'
      }
    }
  }
end

def platform_package_matrix
  {
    'redhat'  => { '7.1'    => platform_package_urls[:linux][:redhat]  },
    'ubuntu'  => { '16.04'  => platform_package_urls[:linux][:debian]  },
    'windows' => { '2012R2' => platform_package_urls[:windows][:msi]   },
    'suse'    => { '12.0'   => platform_package_urls[:linux][:archive] }
  }
end

def environment_combinations
  @env_per ||= [].tap do |array|
    platform_package_matrix.each do |platform, versions|
      versions.each do |version, packages|
        packages.each do |package, url|
          array << [platform, version, package, url]
        end
      end
    end
  end
end

def chef_context_block
  proc do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new({ step_into: [test_resource] }.merge!(runner_params)) do |node|
        node.normal['test_parameters'] = test_params
        node.normal['test_resource'] = test_resource
        node.normal['run_state'].merge!(mock_run_state)
        chef_run_stubs
      end.converge('cerner_splunk_ingredient_test::' + test_recipe)
    end

    let(:run_state) { chef_run.node.run_state['splunk_ingredient'] }

    subject { chef_run }
  end
end

def chef_context(description, &blk)
  context(description, &chef_context_block).class_eval(&blk)
end

def chef_describe(description, &blk)
  describe(description, &chef_context_block).class_eval(&blk)
end
