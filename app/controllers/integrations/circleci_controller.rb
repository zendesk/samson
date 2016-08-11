# frozen_string_literal: true
class Integrations::CircleciController < Integrations::BaseController
  protected

  def payload
    @payload ||= params.fetch('payload', '{}')
  end

  def deploy?
    project && %w[success fixed].include?(status) && !skip?
  end

  def skip?
    contains_skip_token?(message)
  end

  def status
    payload['status']
  end

  def branch
    payload['branch']
  end

  def commit
    payload['vcs_revision']
  end

  def message
    payload['subject']
  end
end
