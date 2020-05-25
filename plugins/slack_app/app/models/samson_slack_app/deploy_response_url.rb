# frozen_string_literal: true
module SamsonSlackApp
  class DeployResponseUrl < ActiveRecord::Base
    belongs_to :deploy, inverse_of: false
  end
end
