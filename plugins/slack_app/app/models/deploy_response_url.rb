# frozen_string_literal: true
class DeployResponseUrl < ActiveRecord::Base
  belongs_to :deploy, inverse_of: nil
end
