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

    def self.log(message, extra_info = {})
      @output_file ||= File.open(ENV['KUBER_LOGFILE'] || File.join(Rails.root, 'log', 'kubernetes.log'), 'a')

      @output_file.write({ message: message }.merge(extra_info).to_json + "\n")
      @output_file.flush
      message
    end
  end
end
