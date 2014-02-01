class NewRelicApplication < ActiveRecord::Base
  belongs_to :stage

  validates :name, presence: true
end
