# frozen_string_literal: true
module Kubernetes
  module Util
    def self.parse_file(contents, filepath)
      filename = File.basename(filepath).downcase

      if filename.ends_with?('.yml', '.yaml')
        # NOTE: this will always return an array of entries
        yaml_safe_load_stream(contents, filename)
      elsif filename.ends_with?('.json')
        JSON.parse(contents)
      else
        fail "Unknown file type: #{filename}"
      end
    end

    def self.log(message, extra_info = {})
      msg_log = {message: message}.merge(extra_info).to_json
      Rails.logger.info(msg_log)
    end

    def self.yaml_safe_load_stream(contents, filename)
      YAML.parse_stream(contents, filename: filename).children.map do |child|
        temp_stream = Psych::Nodes::Stream.new
        temp_stream.children << child
        YAML.safe_load(temp_stream.to_yaml, permitted_classes: [Symbol], aliases: true)
      end
    end
  end
end
