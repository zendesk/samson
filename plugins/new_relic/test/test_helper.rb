# frozen_string_literal: true
require_relative '../../../test/test_helper'

ActiveSupport::TestCase.class_eval do
  def self.with_new_relic_plugin_enabled
    before do
      silence_warnings { SamsonNewRelic.const_set(:API_KEY, '123') }
    end

    after do
      silence_warnings { SamsonNewRelic.const_set(:API_KEY, nil) }
      SamsonNewRelic::Api.instance_variable_set(:@applications, nil) # clear cache
    end
  end
end
