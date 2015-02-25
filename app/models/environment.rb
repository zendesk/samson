class Environment < ActiveRecord::Base
  has_many :deploy_groups

  validates_presence_of :name
  validates_uniqueness_of :name
end
