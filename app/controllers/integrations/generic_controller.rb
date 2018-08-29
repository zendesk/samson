# frozen_string_literal: true

module Integrations
  class GenericController < Integrations::BaseController
    private

    def deploy?
      true
    end

    def deploy
      @deploy ||= params.require(:deploy)
    end

    def commit_params
      @commit_params ||= deploy.require(:commit)
    end

    def branch
      deploy[:branch]
    end

    def commit
      commit_params.require(:sha)
    end

    def message
      commit_params[:message]
    end
  end
end
