# frozen_string_literal: true
#
# Rewrite unhelpful rails default errors
module JsonExceptions
  def self.included(base)
    # default error has very little information
    # http://stackoverflow.com/questions/33704640/how-to-render-correct-json-format-with-raised-error
    base.rescue_from ActiveRecord::RecordInvalid do |exception|
      raise unless request.format.json?
      render_json_error 422, exception.record.errors
    end

    # default error has very little information
    # https://github.com/rails/strong_parameters/issues/157
    base.rescue_from ActionController::ParameterMissing do |exception|
      raise unless request.format.json?
      render_json_error 400, exception.param => ["is required"]
    end

    # otherwise renders a 500 and goes to error notifier
    # https://coderwall.com/p/ea5vtw/validating-rest-queries-with-rails
    base.rescue_from ActionController::UnpermittedParameters do |exception|
      raise unless request.format.json?
      details = exception.params.each_with_object({}) { |p, h| h[p] = ["is not permitted"] }
      render_json_error 400, details
    end

    # renders as {} 422 otherwise which is super unhelpful
    base.rescue_from ActionController::InvalidAuthenticityToken do
      raise unless request.format.json?
      render_json_error 401, "Unauthorized"
    end
  end

  private

  # render json errors as rails does for consistency
  def render_json_error(status, message)
    render json: {status: status, error: message}, status: status
  end
end
