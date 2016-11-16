# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe User do
  describe 'callbacks are loaded to model' do
    it 'calls callbacks after a commit event' do
      SamsonAuditLog::Audit.expects(:log).at_least_once
      User.last.update_attribute(:id, -1)
    end
  end
end
