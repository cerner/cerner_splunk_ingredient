# frozen_string_literal: true

name              'cerner_splunk_ingredient'
maintainer        'Cerner Innovation, Inc.'
maintainer_email  'splunk@cerner.com'
license           'Apache-2.0'
description       'Installs and configures Splunk'
long_description((Pathname.new(__FILE__).dirname + 'README.md').read)
version           '1.0.0'

source_url        'https://github.com/cerner/cerner_splunk_ingredient'
issues_url        'https://github.com/cerner/cerner_splunk_ingredient/issues'

chef_version      '~> 12.16'

supports          'redhat', '>= 6.8'
supports          'ubuntu', '>= 12.04'
supports          'windows', '>= 6.1'

depends           'poise-archive', '~> 1.3.0'
