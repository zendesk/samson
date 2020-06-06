# frozen_string_literal: true
module JsonRenderer
  class ForbiddenIncludesError < RuntimeError
  end

  class << self
    # make sure we are not using sensitive/unsupported values or methods.
    def validate_allowed(field, requested, allowed)
      forbidden = (requested - allowed.map(&:to_s))
      return if forbidden.empty?
      raise(
        JsonRenderer::ForbiddenIncludesError,
        "Forbidden #{field} [#{forbidden.join(",")}] found, allowed #{field} are [#{allowed.join(", ")}]"
      )
    end

    # fill in <association>_ids/<association>_id and objects into the json response
    def add_includes(root, resources, includes)
      associations = {}

      includes.each do |association_name|
        resources.each do |resource, resource_as_json|
          associated = resource.public_send(association_name)
          if associated.is_a?(ActiveRecord::Base)
            resource_as_json["#{association_name}_id"] ||= associated.id
            (associations[association_name.pluralize] ||= []) << associated
          elsif associated.nil?
            resource_as_json["#{association_name}_id"] ||= nil
            associations[association_name.pluralize] ||= []
          else
            resource_as_json["#{association_name.singularize}_ids"] = associated.map(&:id)
            (associations[association_name] ||= []).concat associated
          end
        end
      end

      # add items to the existing collection, but avoid calling as_json multiple times for the same object
      associations.each do |namespace, objects|
        root[namespace] = objects.uniq.map(&:as_json)
      end
    end
  end

  private

  def render_as_json(namespace, resource, pagy, status: :ok, allowed_includes: [])
    # validate includes
    requested_includes = permit_requested(:includes, allowed_includes)

    # validate inlines
    requested_inlines =
      if obj = Array(resource).first
        respond_inlines = (resource_klass = obj.class).respond_to?(:allowed_inlines)
        permit_requested(:inlines, respond_inlines ? resource_klass.allowed_inlines : [])
      else
        []
      end

    # prepare resources for include collection
    resource_json = resource.as_json(methods: requested_inlines)
    resource_list =
      if resource.is_a?(ActiveRecord::Base)
        [[resource, resource_json]]
      else
        resource.zip(resource_json)
      end

    # build reply
    json = {namespace => resource_json}
    add_json_pagination(json, pagy) if pagy
    JsonRenderer.add_includes(json, resource_list, requested_includes)

    yield json if block_given?

    render status: status, json: json
  rescue ActiveRecord::AssociationNotFoundError, JsonRenderer::ForbiddenIncludesError
    render status: :bad_request, json: {status: 400, error: $!.message}
  end

  def permit_requested(field, allowed = [])
    requested = params[field].to_s.split(",")
    return [] if requested.empty?
    JsonRenderer.validate_allowed(field, requested, allowed)
    requested
  end
end
