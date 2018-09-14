class ChangesetFactory
  def self.changeset
    changeset_discriptor.constantize
  end

  def self.pull_request
    "#{changeset_discriptor}::PullRequest".constantize
  end

  def self.attribute_tabs
    "#{changeset_discriptor}::ATTRIBUTE_TABS".constantize
  end

  def self.code_push
    "#{changeset_discriptor}::CodePush".constantize
  end

  def self.issue_comment
    "#{changeset_discriptor}::IssueComment".constantize
  end

  def self.commit
    "#{changeset_discriptor}::Commit".constantize
  end

  private

  def self.changeset_discriptor
    "Samson::#{remote_repository.camelize}::Changeset"
  end

  def self.remote_repository
    Rails.application.config.samson.remote_repository
  end
end
