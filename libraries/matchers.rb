# frozen_string_literal: true

if defined?(ChefSpec)
  ChefSpec.define_matcher :splunk_install
  ChefSpec.define_matcher :splunk_service
  ChefSpec.define_matcher :splunk_conf
  ChefSpec.define_matcher :splunk_app_custom
  ChefSpec.define_matcher :splunk_app_package

  def configure_splunk(path)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_conf, :configure, path)
  end

  def delete_splunk_conf(path)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_conf, :delete, path)
  end

  def install_splunk(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_install, :install, name)
  end

  def uninstall_splunk(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_install, :uninstall, name)
  end

  def install_splunk_app_custom(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_app_custom, :install, name)
  end

  def install_splunk_app_package(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_app_package, :install, name)
  end

  def uninstall_splunk_app_custom(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_app_custom, :uninstall, name)
  end

  def uninstall_splunk_app_package(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_app_package, :uninstall, name)
  end

  def __guarded_restart_splunk_service(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_service, :__guarded_restart, name)
  end

  def desired_restart_splunk_service(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_service, :desired_restart, name)
  end

  def init_splunk_service(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_service, :init, name)
  end

  def restart_splunk_service(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_service, :restart, name)
  end

  def start_splunk_service(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_service, :start, name)
  end

  def stop_splunk_service(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_service, :stop, name)
  end
end
