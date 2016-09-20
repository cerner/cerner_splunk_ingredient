source 'https://rubygems.org'

gem 'berkshelf', '~> 4.3'
gem 'chef', '~> 12.4', ENV['CHEF_VERSION'] || '<= 12.13.37' # Chef 12.14+ requires Ruby 2.2, but we want to test Ruby 2.1 by default
gem 'rubocop', '~> 0.41'
gem 'foodcritic', '~> 6.0'
gem 'chefspec', '~> 5.0'
gem 'hashie', '~> 3.4.6'

group :local do
  gem 'test-kitchen', '~> 1.10'
  gem 'kitchen-vagrant'
  gem 'kitchen-inspec'
  gem 'winrm', '~> 2.0'
  gem 'winrm-fs', '~> 1.0'
  gem 'guard', '~> 2.14'
  gem 'guard-rubocop'
  gem 'guard-foodcritic'
end
