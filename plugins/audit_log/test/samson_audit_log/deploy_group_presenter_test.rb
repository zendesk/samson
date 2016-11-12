# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe 'SamsonAuditLog::DeployGroupPresenter' do
  let(:deploy_group) { DeployGroup.first }

  describe '.present' do
    it 'returns filtered object' do
      object = SamsonAuditLog::DeployGroupPresenter.present(deploy_group)
      object.keys.must_equal [:id, :permalink, :name, :environment, :created_at, :updated_at]
    end
  end
end
