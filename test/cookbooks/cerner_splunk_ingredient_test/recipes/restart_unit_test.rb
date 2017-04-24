# frozen_string_literal: true

node.run_state.merge! node['run_state'].to_hash if node['run_state']

params = node['test_parameters'].to_hash

resource_name = params.delete('resource_name')

splunk_service params['service_name'] || resource_name do
  package params['package'] if params['package']
  install_dir params['install_dir'] if params['install_dir']
  action :nothing
end

splunk_restart resource_name do
  params.each { |prop, val| send(prop, val) }
end
