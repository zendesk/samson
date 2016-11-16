# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployGroup do
  describe 'callbacks are loaded to model' do
    it 'calls callbacks after a commit event' do
      SamsonAuditLog::Audit.expects(:log).at_least_once
      DeployGroup.last.update_attribute(:id, -1)
    end
  end
end
