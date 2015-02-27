class Environment < ActiveRecord::Base
  has_soft_deletion default_scope: true

  has_many :deploy_groups

  validates_presence_of :name
  validates_uniqueness_of :name
end
