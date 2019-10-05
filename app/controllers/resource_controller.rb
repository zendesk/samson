# frozen_string_literal: true
require 'csv'

# Abstract controller that handles all resources, subclasses handle custom logic by overwriting
class ResourceController < ApplicationController
  ADD_MORE = 'Save and add another'
  DEFAULT_BRANCH = "master"

  def index(paginate: true, resources: search_resources)
    assign_resources(
      if paginate
        pagy(
          resources,
          page: params[:page],
          items: [Integer(params[:per_page] || 25), 100].min
        )
      else
        [nil, resources]
      end
    )
    respond_to do |format|
      format.html
      format.json do
        render_as_json resource_name.pluralize, @resources, @pagy, allowed_includes: allowed_includes
      end
      format.csv { render_as_csv @resources }
    end
  end

  def new(template: :new)
    respond_to { |format| format.html { render template } }
  end

  def create(template: :new)
    respond_to do |format|
      format.html do
        if @resource.save
          create_callback

          flash[:notice] = "Created!"
          redirect_after_save
        else
          flash[:alert] = "Failed to create!"
          render template
        end
      end
      format.json do
        @resource.save!
        create_callback
        render_resource_as_json status: :created
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render_resource_as_json }
    end
  end

  def edit
  end

  def update(template: :edit)
    respond_to do |format|
      format.html do
        if @resource.update(resource_params)
          flash[:notice] = "Updated!"
          redirect_after_save
        else
          render template
        end
      end
      format.json do
        @resource.update!(resource_params)
        render_resource_as_json
      end
    end
  end

  def destroy
    success =
      if @resource.respond_to?(:soft_delete)
        @resource.soft_delete(validate: false)
      else
        @resource.destroy
      end
    destroy_callback if success

    respond_to do |format|
      format.html do
        if success
          redirect_to(redirect_to_from_params || resources_path, notice: "Destroyed!")
        else
          error_message = <<~TEXT
            #{resource_class.name.split("::").last} could not be destroyed because:
            #{@resource.errors.full_messages.join(', ')}
          TEXT

          redirect_to @resource, alert: error_message
        end
      end
      format.json do
        success ? head(:ok) : render_json_error(422, @resource.errors)
      end
    end
  end

  private

  def redirect_after_save
    if params[:commit] == ADD_MORE
      redirect_to action: :new, resource_name => params.fetch(resource_name).to_unsafe_h
    else
      redirect_to(redirect_to_from_params || resource_path)
    end
  end

  def search_resources
    resource_class
  end

  # hook
  def create_callback
  end

  # hook
  def destroy_callback
  end

  # hook
  def allowed_includes
    []
  end

  def resource_path
    @resource
  end

  def resources_path
    resource_class
  end

  def render_resource_as_json(**args)
    render_as_json resource_name, @resource, nil, **args, allowed_includes: allowed_includes
  end

  def set_resource
    resource =
      if ['new', 'create'].include?(action_name)
        assign_resource resource_class.new(resource_params)
      else
        finder = (resource_class.respond_to?(:find_by_param!) ? :find_by_param! : :find)
        resource_class.send(finder, params.require(:id))
      end
    assign_resource resource
  end

  def resource_class
    self.class.name.sub('Controller', '').singularize.constantize
  end

  def resource_name
    resource_class.name.underscore.tr('/', '_')
  end

  def assign_resource(value)
    @resource = value
    instance_variable_set :"@#{resource_name}", value
  end

  def assign_resources(args)
    @pagy, @resources = args
    instance_variable_set :"@#{resource_name.pluralize}", @resources
  end

  def resource_params
    if action_name == 'new' && !params[resource_name]
      ActionController::Parameters.new
    else
      params.require(resource_name)
    end
  end

  def render_as_csv(items)
    items = items.limit(nil).to_a # we want all
    count = items.length # triggers loading all to avoid further queries
    columns = (count == 0 ? ["Empty"] : items.first.as_json.keys)

    csv = CSV.generate do |csv|
      csv << columns.map(&:humanize)
      items.each { |item| csv << item.as_json.values }
      csv << ['-', 'count:', count]
      csv << ['-', 'url:', request.original_url]
    end

    file = "#{controller_name}_#{Time.now.to_s(:db).tr(':', '-')}.csv"
    send_data csv, type: :csv, filename: file
  end
end
