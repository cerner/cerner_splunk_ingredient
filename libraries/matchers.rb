# frozen_string_literal: true
if defined?(ChefSpec)
  ChefSpec.define_matcher :splunk_install
  ChefSpec.define_matcher :splunk_service
  ChefSpec.define_matcher :splunk_conf
  ChefSpec.define_matcher :splunk_restart

  def install_splunk(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_install, :install, name)
  end

  def uninstall_splunk(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_install, :uninstall, name)
  end

  def configure_splunk(path)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_conf, :configure, path)
  end

  def start_splunk_service(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_service, :start, name)
  end

  def stop_splunk_service(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_service, :stop, name)
  end

  def restart_splunk_service(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_service, :restart, name)
  end

  def init_splunk_service(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_service, :init, name)
  end

  def ensure_splunk_restart(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_restart, :ensure, name)
  end

  def check_splunk_restart(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_restart, :check, name)
  end

  def clear_splunk_restart(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_restart, :clear, name)
  end

  def install_splunk_app_custom(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_app_custom, :install, name)
  end

  def install_splunk_app_package(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_app_package, :install, name)
  end

  def install_splunk_app_git(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_app_git, :install, name)
  end

  def uninstall_splunk_app_custom(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_app_custom, :uninstall, name)
  end

  def uninstall_splunk_app_package(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_app_package, :uninstall, name)
  end

  def uninstall_splunk_app_git(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_app_git, :uninstall, name)
  end
end
