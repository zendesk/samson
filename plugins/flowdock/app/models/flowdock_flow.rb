# frozen_string_literal: true
class FlowdockFlow < ActiveRecord::Base
  belongs_to :stage, inverse_of: :flowdock_flows
end
