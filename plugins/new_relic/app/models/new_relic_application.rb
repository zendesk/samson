# frozen_string_literal: true
class NewRelicApplication < ActiveRecord::Base
  belongs_to :stage
end
