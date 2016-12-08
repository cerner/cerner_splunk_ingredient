source 'https://rubygems.org'

gem 'berkshelf', '~> 4.3'
gem 'chef', '~> 12.4', ENV['CHEF_VERSION'] || '<= 12.13.37' # Chef 12.14+ requires Ruby 2.2, but we want to test Ruby 2.1 by default
gem 'chefspec', '~> 5.0'
gem 'fauxhai', '~> 3.9.0'
gem 'foodcritic', '~> 6.0'
gem 'hashie', '~> 3.4.6'
gem 'parallel_tests'
gem 'rubocop', '~> 0.41'

group :local do
  gem 'guard', '~> 2.14'
  gem 'guard-foodcritic'
  gem 'guard-rubocop'
  gem 'kitchen-inspec'
  gem 'kitchen-vagrant'
  gem 'test-kitchen', '~> 1.10'
  gem 'winrm', '~> 2.0'
  gem 'winrm-fs', '~> 1.0'
end
