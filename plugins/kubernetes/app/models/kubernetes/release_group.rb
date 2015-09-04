module Kubernetes
  class ReleaseGroup < ActiveRecord::Base
    self.table_name = 'kubernetes_release_groups'

    belongs_to :user
    belongs_to :build
    has_many :releases, class_name: 'Kubernetes::Release', foreign_key: 'kubernetes_release_group_id', inverse_of: :release_group

    validates :build, presence: true
    validates :releases, presence: true
    validate :docker_image_in_registry?, on: :create

    delegate :project, to: :build

    def user
      super || NullUser.new(user_id)
    end

    def deploy_group_ids
      releases.map(&:deploy_group_id)
    end

    def deploy_group_ids=(id_list)
      id_list = id_list.map(&:to_i).select(&:present?)

      ids_to_delete = (deploy_group_ids - id_list)

      releases.each do |rel|
        releases.delete(rel) if ids_to_delete.include?(rel.deploy_group_id)
      end if ids_to_delete.any?

      (id_list - deploy_group_ids).each do |deploy_group_id|
        releases.build(deploy_group_id: deploy_group_id)
      end
    end

    def nested_error_messages
      errors.full_messages + releases.map(&:nested_error_messages).flatten
    end

    private

    def docker_image_in_registry?
      if build && build.docker_repo_digest.blank?
        errors.add(:build, 'Docker image was not pushed to registry')
      end
    end
  end
end
