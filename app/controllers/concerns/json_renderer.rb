# frozen_string_literal: true
module JsonRenderer
  private

  # render a json response <association>_ids and <association>s
  def render_json_with_includes(name, resources, allowed:)
    all = {name => resources.as_json}

    # make sure we are not including sensitive/unsupported associations
    requested = (params[:includes] || "").split(",")
    forbidden = requested - allowed.map(&:to_s)
    if forbidden.any?

      return render_json_error(
        400,
        "Forbidden includes [#{forbidden.join(",")}] found, allowed includes are [#{allowed.join(", ")}]"
      )
    end

    # collect associations and insert _ids placeholders for referencing them
    associations = {}
    requested.each do |association_name|
      resources.each_with_index do |resource, i|
        associated_klass_namespace = resource.association(association_name).klass.name.underscore.pluralize
        associated = resource.public_send(association_name)
        all[name][i]["#{association_name}_ids"] = associated.map(&:id) if associated.respond_to?(:map)
        (associations[associated_klass_namespace] ||= []).concat Array(associated)
      end
    end

    # combine all includes, but avoid calling as_json multiple times for the same object
    associations.each do |namespace, objects|
      all[namespace] = objects.uniq.map(&:as_json)
    end

    render json: all
  end
end
