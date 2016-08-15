# frozen_string_literal: true
class Integrations::SemaphoreController < Integrations::BaseController
  protected

  def deploy?
    params[:result] == 'passed' &&
      !skip?
  end

  def skip?
    contains_skip_token?(message)
  end

  def commit
    params[:commit][:id]
  end

  def branch
    params[:branch_name]
  end

  def message
    params[:commit][:message]
  end
end
