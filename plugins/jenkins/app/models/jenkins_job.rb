class JenkinsJob < ActiveRecord::Base
  belongs_to :deploy
end
