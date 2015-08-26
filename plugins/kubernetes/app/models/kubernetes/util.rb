module Kubernetes
  module Util
    def self.parse_file(contents, filepath)
      filename = File.basename(filepath).downcase

      if filename.ends_with?('.yml', '.yaml')
        # NOTE: this will always return an array of entries
        YAML.load_stream(contents, filepath)
      elsif filename.ends_with?('.json')
        JSON.parse(contents)
      else
        fail "Unknown file type: #{filename}"
      end
    end
  end
end
