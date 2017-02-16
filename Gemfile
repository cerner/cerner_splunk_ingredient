# frozen_string_literal: true
source 'https://rubygems.org'

gem 'berkshelf', '~> 5.3'
gem 'chef', '~> 12.13', ENV['CHEF_VERSION'] || '<= 12.13.37' # Allow testing both versions of Chef
gem 'chefspec', '~> 5.3'
gem 'fauxhai', '~> 3.10'
gem 'foodcritic', '~> 8.0'
gem 'hashie', '~> 3.4.6'
gem 'parallel_tests'
gem 'rubocop', '~> 0.46'

group :local do
  gem 'guard', '~> 2.14'
  gem 'kitchen-inspec'
  gem 'kitchen-vagrant'
  gem 'test-kitchen', '~> 1.14'
  gem 'winrm', '~> 2.1'
  gem 'winrm-fs', '~> 1.0'
end
