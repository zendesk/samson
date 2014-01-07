class Deploy < ActiveRecord::Base
  belongs_to :stage
  belongs_to :job
end
