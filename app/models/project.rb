require 'soft_deletion'

class Project < ActiveRecord::Base
  has_soft_deletion

  validates_presence_of :name

  has_many :stages
  has_many :deploys, through: :stages
  has_many :jobs, -> { order("created_at DESC") }

  accepts_nested_attributes_for :stages

  def to_param
    "#{id}-#{name.parameterize}"
  end

  def repo_name
    name.parameterize("_")
  end
end
