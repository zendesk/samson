# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe Deploy do
  describe '#triggering_deploy' do
    let(:deploy) { deploys(:succeeded_test) }

    it 'references triggering deploy' do
      other_deploy = deploys(:succeeded_production_test)

      deploy.update_column(:triggering_deploy_id, other_deploy.id)
      deploy.triggering_deploy.must_equal other_deploy
    end

    it 'can have a null triggering deploy' do
      new_deploy = Deploy.new(deploy.attributes.except('id', 'created_at', 'updated_at'))
      new_deploy.triggering_deploy_id.must_equal nil

      assert_predicate new_deploy, :valid?
    end
  end
end
