# frozen_string_literal: true
class UserProjectRole < ActiveRecord::Base
  include HasRole

  has_paper_trail skip: [:updated_at, :created_at]

  belongs_to :project
  belongs_to :user

  ROLES = [Role::DEPLOYER, Role::ADMIN].freeze

  validates_presence_of :project, :user
  validates :role_id, inclusion: { in: ROLES.map(&:id) }
  validates_uniqueness_of :project_id, scope: :user_id

  after_save :trigger_user_change
  after_destroy :trigger_user_change

  private

  # tested via user_test.rb
  def trigger_user_change
    user.record_project_role_change
  end
end
