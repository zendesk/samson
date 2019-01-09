# frozen_string_literal: true

# Implements tsort, copied from stdlib docs
class G
  include TSort
  def initialize(g)
    @g = g
  end

  def tsort_each_child(n, &b)
    @g[n].each(&b)
  end

  def tsort_each_node(&b)
    @g.each_key(&b)
  end
end

def make_ref_hash(h)
  res = {}
  h.each do |source_key, source_value|
    res[source_key] = []
    h.each_key do |target_key|
      check = "$(#{target_key})"
      if source_value && source_value.include?(check)
        res[source_key].concat([target_key])
      end
    end
  end
  res
end

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
      msg_log = {message: message}.merge(extra_info).to_json
      Rails.logger.info(msg_log)
    end

    def self.env_sort!(env)
      env_hash = Hash[*env.collect { |v| [v[:name], v[:value]] }.flatten]
      ref_hash = make_ref_hash(env_hash)

      begin
        order = G.new(ref_hash).tsort
        env.sort_by! { |e| order.index(e[:name]) }
      rescue TSort::Cyclic => error
        raise Samson::Hooks::UserError, "Could not sort environment variables, #{error.message}"
      end
    end
  end
end
