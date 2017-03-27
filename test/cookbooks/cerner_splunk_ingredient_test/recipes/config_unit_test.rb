# frozen_string_literal: true

node.run_state.merge! node['run_state'].to_hash if node['run_state']

params = node['test_parameters'].to_hash

splunk_conf params.delete('path') || 'system/indexes.conf' do
  params.each { |prop, val| send(prop, val) }
end
