# frozen_string_literal: true
module Samson
  class RedeployParams
    class << self
      def call(deploy)
        new(deploy).call
      end
    end

    def initialize(deploy)
      @deploy = deploy
    end

    # Applies different logic depending on the class of each of the deploy
    # parameters, so it supports nested paramaters based on object relations
    def call
      params = Samson::Hooks.fire(:deploy_permitted_params).flatten(1)
      params.each_with_object(reference: @deploy.reference) do |param, collection|
        case param
        when String, Symbol
          collection[param] = @deploy.public_send(param)
        when Hash
          nested_redeploy_params(collection, param)
        else
          raise "Unsupported deploy param class: `#{param.class}` for `#{param}`."
        end
      end
    end

    private

    def nested_redeploy_params(collection, params)
      params.each_with_object(collection) do |(key, attributes), nested|
        if key.to_s.end_with?('attributes')
          nested[key] = deploy_relation_attributes(key, attributes)
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
