class Environment < ActiveRecord::Base
  include Permalinkable

  has_soft_deletion default_scope: true
  has_many :deploy_groups

  validates_presence_of :name
  validates_uniqueness_of :name

  private

  def permalink_base
    name
  end
end
