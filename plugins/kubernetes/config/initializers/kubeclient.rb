# frozen_string_literal: true
# replace this once https://github.com/abonas/kubeclient/pull/306 is released
# with always passing `as: :parsed_json` to each newly Kubeclient::Client.new
require 'kubeclient'
Kubeclient::Client.class_eval do
  def get_entities(*args, options)
    if options[:as]
      super
    else
      JSON.parse(super(*args, options.merge(as: :raw)), symbolize_names: true)
    end
  end

  def get_entity(*args, options)
    if options[:as]
      super
    else
      JSON.parse(super(*args, options.merge(as: :raw)), symbolize_names: true)
    end
  end
end
