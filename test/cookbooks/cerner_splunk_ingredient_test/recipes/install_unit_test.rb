node.run_state.merge! node['run_state'].to_hash if node['run_state']

params = node['test_parameters']

splunk_install params['name'] || 'splunk' do
  params.each { |prop, val| send(prop, val) }
end
