# frozen_string_literal: true
class Project < ActiveRecord::Base
  has_soft_deletion default_scope: true unless self < SoftDeletion::Core
  has_paper_trail skip: [:updated_at, :created_at]

  include Permalinkable
  include Searchable

  validates :name, :repository_url, presence: true
  validate :valid_repository_url
  validate :validate_can_release
  before_create :generate_token
  after_save :clone_repository, if: :repository_url_changed?
  before_update :clean_old_repository, if: :repository_url_changed?
  after_soft_delete :clean_repository
  before_soft_delete :destroy_user_project_roles

  has_many :builds, dependent: :destroy
  has_many :releases, dependent: :destroy
  has_many :stages, dependent: :destroy
  has_many :deploys
  has_many :jobs, -> { order(id: :desc) }
  has_many :webhooks, dependent: :destroy
  has_many :outbound_webhooks, dependent: :destroy
  has_many :commands, dependent: :destroy
  has_many :macros, dependent: :destroy
  has_many :user_project_roles, dependent: :destroy
  has_many :users, through: :user_project_roles

  belongs_to :build_command, class_name: 'Command'

  # For permission checks on callbacks. Currently used in private plugins.
  attr_accessor :current_user

  scope :alphabetical, -> { order('name') }
  scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
  scope :with_deploy_groups, -> { includes(stages: [:deploy_groups]) }

  scope :ordered_for_user, ->(user) {
    select('projects.*, count(stars.id) as star_count').
      joins("left outer join stars on stars.user_id = #{sanitize(user.id)} and stars.project_id = projects.id").
      group('projects.id').
      order('star_count desc').
      alphabetical
  }

  scope :search, ->(name) { where("name like ?", "%#{name}%") }

  def docker_repo(registry)
    File.join(registry.base, permalink_base)
  end

  # Whether to create new releases when the branch is updated.
  #
  # branch - The String name of the branch in question.
  #
  # Returns true if new releases should be created, false otherwise.
  def create_release?(branch, service_type, service_name)
    release_branch == branch && Webhook.source_matches?(release_source, service_type, service_name)
  end

  # Whether to create a new docker image when the branch is updated.
  #
  # branch - The String name of the branch in question.
  #
  # Returns true if new releases should be created, false otherwise.
  def build_docker_image_for_branch?(branch)
    branch && docker_release_branch == branch
  end

  # The user/repo part of the repository URL.
  def user_repo_part
    # GitHub allows underscores, hyphens and dots in repo names
    # but only hyphens in user/organisation names (as well as alphanumeric).
    repository_url.scan(%r{[:/]([A-Za-z0-9-]+/[\w.-]+?)(?:\.git)?$}).join
  end

  # TODO: remove, this is misleading
  def github_repo
    user_repo_part
  end

  # TODO: remove, this is misleading
  def gitlab_repo
    user_repo_part
  end

  def repository_directory
    @repository_directory ||= Digest::MD5.hexdigest([repository_url, id].join)
  end

  def webhook_stages_for(branch, service_type, service_name)
    webhooks.for_source(service_type, service_name).for_branch(branch).map(&:stage)
  end

  def repository_homepage
    if github?
      repository_homepage_github
    elsif gitlab?
      repository_homepage_gitlab
    else
      ""
    end
  end

  def github?
    repository_url.include? Rails.application.config.samson.github.web_url.split("://", 2).last
  end

  def gitlab?
    repository_url.include? Rails.application.config.samson.gitlab.web_url.split("://", 2).last
  end

  def release_prior_to(release)
    releases.where('id < ?', release.id).order(:id).last
  end

  def repository
    @repository ||= GitRepository.new(repository_url: repository_url, repository_dir: repository_directory)
  end

  def last_deploy_by_group(before_time, include_failed_deploys: false)
    releases = deploys_by_group(before_time, include_failed_deploys)
    releases.map { |group_id, deploys| [group_id, deploys.sort_by(&:updated_at).last] }.to_h
  end

  def url
    Rails.application.routes.url_helpers.project_url(self)
  end

  private

  def repository_homepage_github
    "#{Rails.application.config.samson.github.web_url}/#{github_repo}"
  end

  def repository_homepage_gitlab
    "#{Rails.application.config.samson.gitlab.web_url}/#{gitlab_repo}"
  end

  def deploys_by_group(before, include_failed_deploys = false)
    stages.each_with_object({}) do |stage, result|
      stage_filter = include_failed_deploys ? stage.deploys : stage.deploys.successful.where(release: true)
      deploy = stage_filter.where("deploys.updated_at <= ?", before.to_s(:db)).first
      next unless deploy
      stage.deploy_groups.sort_by(&:natural_order).each do |deploy_group|
        result[deploy_group.id] ||= []
        result[deploy_group.id] << deploy
      end
    end
  end

  def permalink_base
    parts = repository_url.to_s.split('/')
    parts.last.to_s.sub(/\.git/, '').presence || parts[-2].to_s
  end

  def generate_token
    self.token = SecureRandom.hex
  end

  def clone_repository
    Thread.new do
      begin
        output = repository.executor.output
        repository.exclusive(output: output, holder: 'Initial Repository Setup') do
          unless repository.update_local_cache!
            log.error("Could not clone git repository #{repository_url} for project #{name} - #{output.string}")
          end
        end
      rescue => e
        alert_clone_error!(e)
      end
    end
  end

  def clean_repository
    repository.clean!
  end

  def log
    Rails.logger
  end

  def clean_old_repository
    GitRepository.new(repository_url: repository_url_was, repository_dir: old_repository_dir).clean!
    @repository, @repository_directory = nil
  end

  def old_repository_dir
    Digest::MD5.hexdigest([repository_url_was, id].join)
  end

  def alert_clone_error!(exception)
    message = "Could not clone git repository #{repository_url} for project #{name}"
    log.error("#{message} - #{exception.message}")
    Airbrake.notify(
      exception,
      error_message: message,
      parameters: {
        project_id: id
      }
    )
  end

  def valid_repository_url
    return if repository.valid_url?
    errors.add(:repository_url, "is not valid or accessible")
  end

  def validate_can_release
    return if release_branch.blank? || release_branch_was.present?
    return if ReleaseService.new(self).can_release?
    errors.add(
      :release_branch,
      "could not be set. Samson's github user needs 'Write' permission to push new tags to #{user_repo_part}."
    )
  end

  def destroy_user_project_roles
    user_project_roles.each(&:destroy)
  end
end
