# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

# full test of all callbacks, decorator tests validate that model callbacks are loaded with a simple test
describe AuditLog do
  it 'calls SamsonAuditLog::Audit.log on create action' do
    SamsonAuditLog::Audit.expects(:log).with(:info, PaperTrail.whodunnit, 'created User', instance_of(User)).once
    User.create(name: 'foo')
  end

  it 'calls SamsonAuditLog::Audit.log on destroy action' do
    SamsonAuditLog::Audit.expects(:log).with(:info, PaperTrail.whodunnit, 'deleted User', instance_of(User)).once
    User.last.destroy
  end

  it 'calls SamsonAuditLog::Audit.log on soft_deletion action' do
    SamsonAuditLog::Audit.expects(:log).with(:info, PaperTrail.whodunnit, 'deleted User', instance_of(User)).once
    User.last.soft_delete
  end

  it 'calls SamsonAuditLog::Audit.log on update action with whodunnit_user set' do
    PaperTrail.with_whodunnit_user(User.first) do
      SamsonAuditLog::Audit.expects(:log).with(:info, User.first, 'updated User', instance_of(User)).once
      User.last.update_attribute(:role_id, 2)
    end
  end
end
