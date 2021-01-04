# frozen_string_literal: true
class Integrations::TravisController < Integrations::BaseController
  protected

  def payload
    @payload ||= JSON.parse(params.fetch('payload', '{}'))
  end

  def deploy?
    project &&
      ['Passed', 'Fixed'].include?(payload['status_message']) &&
      payload['type'] == 'push'
  end

  def branch
    payload['branch']
  end

  def commit
    payload['commit']
  end

  def message
    payload['message']
  end
end
