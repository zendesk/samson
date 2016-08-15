# frozen_string_literal: true
class Integrations::JenkinsController < Integrations::BaseController
  protected

  def deploy?
    params[:build][:status] == 'SUCCESS'
  end

  def commit
    params[:build][:scm][:commit]
  end

  def branch
    params[:build][:scm][:branch]
  end
end
