class Release < ActiveRecord::Base
  belongs_to :project
  belongs_to :author, polymorphic: true

  def self.sort_by_newest
    order("created_at DESC")
  end

  def version
    "v#{number}"
  end
end
