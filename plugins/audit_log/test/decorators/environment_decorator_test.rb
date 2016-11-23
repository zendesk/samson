# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Environment do
  describe 'callbacks are loaded to model' do
    it 'calls callbacks after a commit event' do
      SamsonAuditLog::Audit.expects(:log).at_least_once
      Environment.last.update_attribute(:permalink, 'foo')
    end
  end
end
