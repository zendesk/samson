class StageCommand < ActiveRecord::Base
  belongs_to :stage
  belongs_to :command, autosave: true
end
