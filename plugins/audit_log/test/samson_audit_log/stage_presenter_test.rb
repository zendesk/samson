# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe 'SamsonAuditLog::DeployPresenter' do
  let(:stage) { Stage.first }

  describe '.present' do
    it 'returns filtered object' do
      object = SamsonAuditLog::StagePresenter.present(stage)
      object.keys.must_equal [:id, :name, :project, :no_code_deployed, :created_at, :updated_at]
      object[:project].must_equal SamsonAuditLog::ProjectPresenter.present(stage.project)
    end
  end
end
