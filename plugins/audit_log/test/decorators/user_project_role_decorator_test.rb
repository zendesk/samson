# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe UserProjectRole do
  describe 'callbacks are loaded to model' do
    it 'calls callbacks after a commit event' do
      SamsonAuditLog::Audit.expects(:log).at_least_once
      UserProjectRole.last.update_attribute(:id, -1)
    end
  end
end
