# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe AuditOnAssociation do
  let(:command) { commands(:echo) }

  it "triggers a audit when association changes" do
    command.update_attribute(:command, 'new')
    audits = command.reload.stages.first.audits.all
    audits.size.must_equal 1
    audits.first.audited_changes.must_equal("script" => ["echo hello", "new"])
  end

  it "does not trigger audit when association did not change significatly" do
    command.update_attribute(:project, nil)
    command.reload.stages.first.audits.size.must_equal 0
  end
end
