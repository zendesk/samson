# frozen_string_literal: true
class NewRelicApplication < ActiveRecord::Base
  belongs_to :stage, inverse_of: :new_relic_applications
end
