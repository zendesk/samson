# frozen_string_literal: true
class Changeset::CheckSuite
  attr_reader :repo, :data

  def initialize(repo, data)
    @repo = repo
    @data = data
  end

  def self.changeset_from_webhook(project, payload)
    new(project.repository_path, payload)
  end

  def self.valid_webhook?(payload)
    payload['check_suite']['status'] == 'completed' && payload['check_suite']['conclusion'] == 'success'
  end

  def sha
    data['check_suite']['head_sha']
  end

  def branch
    data['check_suite']['head_branch']
  end

  def message
    nil
  end

  def service_type
    'check_suite' # Samson webhook category
  end
end
