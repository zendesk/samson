# frozen_string_literal: true
DeploysHelper.class_eval do
  def redeploy_button
    return if @deploy.job.active?

    html_options = {method: :post}
    if @deploy.succeeded?
      html_options[:class] = 'btn btn-default'
      html_options[:data] = {
        toggle: 'tooltip',
        placement: 'auto bottom'
      }
      html_options[:title] = 'Why? This deploy succeeded.'
    else
      html_options[:class] = 'btn btn-danger'
    end

    link_to "Redeploy",
      project_stage_deploys_path(
        @project,
        @deploy.stage,
        deploy: redeploy_params
      ),
      html_options
  end

  private

  # Applies different logic depending on the class of each of the deploy
  # parameters, so it supports nested paramaters based on object relations
  def redeploy_params
    params = Samson::Hooks.fire(:deploy_permitted_params).flatten(1)
    params.each_with_object(reference: @deploy.reference) do |param, collection|
      case param
      when String, Symbol
        collection[param] = @deploy.public_send(param)
      when Hash
        nested_redeploy_params(collection, param)
      else
        collection
      end
    end
  end

  def nested_redeploy_params(collection, params)
    params.each_with_object(collection) do |(key, attributes), nested|
      if key.to_s.ends_with?('attributes')
        nested[key] = deploy_relation_attributes(key, attributes)
      end
      nested
    end
  end

  # currently, one has_many relations are supported
  def deploy_relation_attributes(key, attributes)
    relation_name = key.to_s.gsub(/_attributes$/, '')
    @deploy.public_send(relation_name).map do |item|
      (attributes - [:id, :_destroy]).each_with_object({}) do |attribute, hash|
        hash[attribute] = item.public_send(attribute)
      end
    end
  end
end
