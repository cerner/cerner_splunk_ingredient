# frozen_string_literal: true

guard :rubocop do
  watch(/.+\.rb$/)
  watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
end

guard :foodcritic, cookbook_paths: '.', cli: ['-f', 'any'] do
  watch(%r{resources/.+\.rb$})
  watch(/metadata\.rb$/)
end
