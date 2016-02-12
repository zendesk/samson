module Kubernetes
  class Release < ActiveRecord::Base
    include Kubernetes::HasStatus

    self.table_name = 'kubernetes_releases'

    belongs_to :user
    belongs_to :build
    has_many :release_docs, class_name: 'Kubernetes::ReleaseDoc', foreign_key: 'kubernetes_release_id'
    has_many :deploy_groups, through: :release_docs

    delegate :project, to: :build

    validates :build, presence: true
    validates :status, inclusion: STATUSES
    validate :docker_image_in_registry?, on: :create

    scope :not_dead, -> { where.not(status: :dead) }
    scope :excluding, ->(ids) { where.not(id: ids) }
    scope :with_not_dead_release_docs, -> { joins(:release_docs).where.not(Kubernetes::ReleaseDoc.table_name => { status: :dead }) }

    def release_is_live!
      finish_deploy(:live)
    end

    def fail!
      finish_deploy(:failed)
      release_docs.each { |release_doc|
        release_doc.fail! unless release_doc.live?
      }
    end

    def release_metadata
      {
        release_id: id.to_s,
        project_id: build.project.id.to_s
      }
    end

    def user
      super || NullUser.new(user_id)
    end

    def nested_error_messages
      errors.full_messages + release_docs.flat_map(&:nested_error_messages)
    end

    def docs_by_role
      @docs_by_role ||= release_docs.each_with_object({}) do |rel_doc, hash|
        hash[rel_doc.kubernetes_role.label_name] = rel_doc
      end
    end

    # Creates a new Kubernetes Release and corresponding ReleaseDocs
    def self.create_release(params)
      Kubernetes::Release.transaction do
        release = create(params.except(:deploy_groups))
        if release.persisted?
          release.create_release_docs(params)
        end
        release
      end
    end

    # Creates a ReleaseDoc per each DeployGroup and Role combination.
    def create_release_docs(params)
      params[:deploy_groups].to_a.each do |dg|
        dg[:roles].to_a.each do |role|
          release_docs.create!(deploy_group_id: dg[:id], kubernetes_role_id: role[:id], replica_target: role[:replicas])
        end
      end
      raise 'No Kubernetes::ReleaseDoc has been created' if release_docs.empty?
    end

    def release_doc_for(deploy_group_id, role_id)
      release_docs.find_by(deploy_group_id: deploy_group_id, kubernetes_role_id: role_id)
    end

    def update_status(release_doc)
      case
      when release_docs.all?(&:live?) then self.status = :live
      when release_docs.all?(&:dead?) then self.status = :dead
      when release_doc.spinning_up? then self.status = :spinning_up
      when release_doc.spinning_down? then self.status = :spinning_down
      when release_docs.any?(&:dead?) then self.status = :spinning_down
      end
      save!
    end

    private

    def docker_image_in_registry?
      if build && build.docker_repo_digest.blank? && build.docker_ref.blank?
        errors.add(:build, 'Docker image was not pushed to registry')
      end
    end

    def finish_deploy(status)
      update_attributes!(status: status, deploy_finished_at: Time.now)
    end
  end
end
