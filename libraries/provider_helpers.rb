module CernerSplunk
  # Mixin Helper methods for Splunk Ingredient resources' providers
  module ProviderHelpers
    def changed?(*properties)
      converge_if_changed(*properties) do
      end
    end

    def deep_copy(source, destination)
      source = Pathname.new(source)
      destination = Pathname.new(destination)

      files = []
      directories = [source]
      until directories.empty?
        current_dirs = Array.new(directories)
        directories.clear

        current_dirs.each do |path|
          path.each_child do |child|
            if child.directory?
              directories.push(child)
            else
              files.push(child)
            end
          end
        end
      end

      files.each do |source_file|
        relative_path = source_file.relative_path_from(source)
        file((destination + relative_path).to_s) do
          content source_file.read
          action :create
        end
      end
    end
  end
end
