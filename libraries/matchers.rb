if defined?(ChefSpec)
  def install_splunk(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_install, :install, name)
  end

  def uninstall_splunk(name)
    ChefSpec::Matchers::ResourceMatcher.new(:splunk_install, :uninstall, name)
  end
end
