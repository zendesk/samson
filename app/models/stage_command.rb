class StageCommand < ActiveRecord::Base
  belongs_to :stage
  belongs_to :command
end
