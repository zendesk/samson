class ProjectRole < ActiveRecord::Base
  belongs_to :project, inverse_of: :roles

  DEPLOY_STRATEGIES = ['rolling_update', 'kill_and_restart']

  validates :project, presence: true
  validates :name, presence: true
  validates :deploy_strategy, presence: true, inclusion: DEPLOY_STRATEGIES
  validates :replicas, presence: true, numericality: { greater_than: 0 }
  validates :ram, presence: true, numericality: { greater_than: 0 }
  validates :cpu, presence: true, numericality: { greater_than: 0 }
end
