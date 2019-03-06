# frozen_string_literal: true
class Build < ActiveRecord::Base
  SHA1_REGEX = /\A[0-9a-f]{40}\Z/i
  SHA256_REGEX = /\A(sha256:)?[0-9a-f]{64}\Z/i
  DIGEST_REGEX = /\A[\w.-]+[\w.-]*(:\d+)?[\w.\/-]*@sha256:[0-9a-f]{64}\Z/i

  belongs_to :project
  belongs_to :docker_build_job, class_name: 'Job', optional: true
  belongs_to :creator, class_name: 'User', foreign_key: 'created_by'
  has_many :deploys, dependent: nil

  before_validation :nil_out_blanks
  before_validation :make_default_dockerfile_and_image_name_not_collide, on: :create

  validate :validate_docker_repo_digest_matches_git_sha, on: :create
  validate :validate_git_reference, on: :create
  validates :project, presence: true
  validates :git_sha, allow_nil: true, format: SHA1_REGEX
  validates :dockerfile, presence: true, unless: :external?
  [:dockerfile, :image_name].each do |attribute|
    validates(
      :git_sha,
      allow_nil: true,
      uniqueness: {scope: attribute, message: "already exists with this #{attribute}"},
      if: attribute
    )
  end
  validates :docker_repo_digest, format: DIGEST_REGEX, allow_nil: true
  validates :external_url, format: /\Ahttps?:\/\/\S+\z/, allow_nil: true
  validates :external_status, inclusion: Job::VALID_STATUSES, allow_nil: true

  before_create :assign_number

  def self.cancel_stalled_builds
    builds_to_cancel = where('created_at < ?', Rails.application.config.samson.deploy_timeout.seconds.ago).
      where(external_status: Job::ACTIVE_STATUSES)
    builds_to_cancel.find_each { |b| b.update_attributes(external_status: 'cancelled') }
  end

  def nice_name
    name.presence || "Build #{id}"
  end

  def commit_url
    "#{project.repository_homepage}/tree/#{git_sha}"
  end

  def create_docker_job
    create_docker_build_job(
      project: project,
      user_id: created_by || NullUser.new(0).id,
      command: '# Build docker image',
      commit:  git_sha,
      tag:     git_ref
    )
  end

  def url
    Rails.application.routes.url_helpers.project_build_url(project, self)
  end

  def active?
    if external?
      !docker_repo_digest? && (!external_status || Job::ACTIVE_STATUSES.include?(external_status))
    else
      docker_build_job&.active?
    end
  end

  def duration
    if external?
      updated_at - created_at if created_at.to_i != updated_at.to_i
    else
      docker_build_job&.duration
    end
  end

  def external?
    external_status.present? || external_url.present?
  end

  private

  def nil_out_blanks
    [:docker_repo_digest, :image_name, :dockerfile].each do |attribute|
      send("#{attribute}=", send(attribute).presence) if changes_include? attribute
    end
  end

  # if we enforce uniqueness via image_name then having a default dockerfile set will break that uniqueness
  def make_default_dockerfile_and_image_name_not_collide
    self.dockerfile = nil if dockerfile == 'Dockerfile' && image_name
  end

  def validate_docker_repo_digest_matches_git_sha
    return if git_sha.present? || docker_repo_digest.blank?
    errors.add(:git_sha, 'supply git_sha when using docker_repo_digest')
  end

  def validate_git_reference
    if git_ref.blank? && git_sha.blank?
      errors.add(:git_ref, 'must be specified')
      return
    end

    return if errors.include?(:git_ref) || errors.include?(:git_sha)

    if git_ref.present?
      commit = project.repository.commit_from_ref(git_ref)
      if commit
        self.git_sha = commit unless git_sha.present?
      else
        errors.add(:git_ref, 'is not a valid reference')
      end
    elsif git_sha.present?
      unless project.repository.commit_from_ref(git_sha)
        errors.add(:git_sha, 'is not a valid SHA for this project')
      end
    end
  end

  def assign_number
    biggest_number = project.builds.maximum(:number) || 0
    self.number = biggest_number + 1
  end
end
