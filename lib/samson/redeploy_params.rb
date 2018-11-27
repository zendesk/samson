# frozen_string_literal: true
module Samson
  class RedeployParams
    def initialize(deploy)
      @deploy = deploy
    end

    # Applies different logic depending on the class of each of the deploy
    # parameters, so it supports nested parameters based on object relations
    def to_hash
      DeploysController.deploy_permitted_params.each_with_object({}) do |param, collection|
        case param
        when String, Symbol
          collection[param] = @deploy.public_send(param)
        when Hash
          add_nested_redeploy_params!(collection, param)
        else
          raise "Unsupported deploy param class: `#{param.class}` for `#{param}`."
        end
      end
    end

    private

    def add_nested_redeploy_params!(collection, params)
      params.each do |(key, attributes)|
        if key.to_s.end_with?('attributes')
          collection[key] = deploy_relation_attributes(key, attributes)
        end
      end
    end

    # currently, this only supports `has_many` relations, cause the public_method
    # we call on the instance is expected to return an array
    def deploy_relation_attributes(key, attributes)
      relation_name = key.to_s.sub(/_attributes$/, '')
      @deploy.public_send(relation_name).map do |item|
        (attributes - [:id, :_destroy]).each_with_object({}) do |attribute, hash|
          hash[attribute] = item.public_send(attribute)
        end
      end
    end
  end
end
