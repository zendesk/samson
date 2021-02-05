# frozen_string_literal: true
class Changeset::CodePush
  attr_reader :repo, :data

  def initialize(repo, data)
    @repo = repo
    @data = data
  end

  def self.changeset_from_webhook(project, payload)
    new(project.repository_path, payload)
  end

  # skip pushes that delete the branch, we can't deploy these
  def self.valid_webhook?(payload)
    !payload['deleted']
  end

  def sha
    data['after']
  end

  def branch
    data['ref'][/\Arefs\/heads\/(\S+)\z/, 1]
  end

  def message
    data['head_commit']&.[]('message')
  end

  def service_type
    'code' # Samson webhook category
  end
end
