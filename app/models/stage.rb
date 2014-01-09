class Stage < ActiveRecord::Base
  belongs_to :project
  has_many :deploys
  default_scope { order(:order) }
end
