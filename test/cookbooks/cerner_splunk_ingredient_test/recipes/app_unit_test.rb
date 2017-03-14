# frozen_string_literal: true
node.run_state.merge! node['run_state'].to_hash if node['run_state']

params = node['test_parameters'].to_hash

method(node['test_resource']).call params.delete('name') || 'test_app' do
  params.each { |prop, val| send(prop, val) unless val.nil? }
end
