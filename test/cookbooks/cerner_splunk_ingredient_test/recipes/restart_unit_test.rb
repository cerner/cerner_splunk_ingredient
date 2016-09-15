node.run_state.merge! node['run_state'].to_hash if node['run_state']

params = node['test_parameters']

splunk_service params['name'] do
  action :nothing
end

splunk_restart params['name'] do
  params.each { |prop, val| send(prop, val) }
end
