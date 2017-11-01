# frozen_string_literal: true
module JsonRenderer
  class ForbiddenIncludesError < RuntimeError
  end

  class << self
    # make sure we are not including sensitive/unsupported associations
    def validate_includes(requested, allowed)
      forbidden = (requested - allowed.map(&:to_s))
      return if forbidden.empty?
      raise(
        JsonRenderer::ForbiddenIncludesError,
        "Forbidden includes [#{forbidden.join(",")}] found, allowed includes are [#{allowed.join(", ")}]"
      )
    end

    # fill in <association>_ids/<association>_id and objects into the json response
    def add_includes(root, resources, includes)
      associations = {}

      includes.each do |association_name|
        resources.each do |resource, resource_as_json|
          associated = resource.public_send(association_name)
          if associated.is_a?(ActiveRecord::Base) || associated.nil?
            resource_as_json["#{association_name}_id"] ||= associated&.id
            (associations[association_name.pluralize] ||= []) << associated
          else
            resource_as_json["#{association_name.singularize}_ids"] = associated.map(&:id)
            (associations[association_name] ||= []).concat associated
          end
        end
      end

      # add items to the existing collection, but avoid calling as_json multiple times for the same object
      associations.each do |namespace, objects|
        root[namespace] = objects.uniq.as_json # can remove as_json once serializers are gone
      end
    end
  end

  private

  def render_as_json(namespace, resource, status: :ok, allowed_includes: [])
    # validate includes
    requested_includes = (params[:includes] || "").split(",")
    JsonRenderer.validate_includes(requested_includes, allowed_includes)

    # prepare resources for include collection
    resource_json = resource.as_json
    resource_list =
      if resource.is_a?(ActiveRecord::Base)
        [[resource, resource_json]]
      else
        resource.zip(resource_json)
      end

    # build reply
    json = {namespace => resource_json}
    JsonRenderer.add_includes(json, resource_list, requested_includes)

    render status: status, json: json
  rescue ActiveRecord::AssociationNotFoundError, JsonRenderer::ForbiddenIncludesError
    render status: 400, json: {status: 400, error: $!.message}
  end
end
