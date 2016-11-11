# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe 'SamsonAuditLog::DeployPresenter' do
  let(:deploy) { Deploy.first }

  describe '.present' do
    it 'returns filtered object with no buddy' do
      object = SamsonAuditLog::DeployPresenter.present(deploy)
      object.keys.must_equal [:id, :stage, :reference, :deployer, :buddy, :started_at, :created_at, :updated_at]
      object[:stage].must_equal SamsonAuditLog::StagePresenter.present(deploy.stage)
      object[:deployer].must_equal SamsonAuditLog::UserPresenter.present(deploy.job.user)
      object[:buddy].must_be_nil
    end

    it 'returns filtered object with with buddy' do
      deploy.buddy = User.last
      object = SamsonAuditLog::DeployPresenter.present(deploy)
      object.keys.must_equal [:id, :stage, :reference, :deployer, :buddy, :started_at, :created_at, :updated_at]
      object[:stage].must_equal SamsonAuditLog::StagePresenter.present(deploy.stage)
      object[:deployer].must_equal SamsonAuditLog::UserPresenter.present(deploy.job.user)
      object[:buddy].must_equal SamsonAuditLog::UserPresenter.present(deploy.buddy)
    end
  end
end
