class Webhook < ActiveRecord::Base
  belongs_to :project
  belongs_to :stage
end
