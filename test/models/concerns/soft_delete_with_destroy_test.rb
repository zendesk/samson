# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe SoftDeleteWithDestroy do
  describe 'destroy' do
    let(:project) { projects(:test) }

    it 'destroys dependent: :destroy relations before soft_delete' do
      assert_difference 'StageCommand.count', -2 do
        project.soft_delete!(validate: false)
      end
    end

    it "does not destroy when validations fail" do
      assert_difference 'StageCommand.count', 0 do
        project.name = nil
        refute project.soft_delete
      end
    end

    it 'does nothing on regular save' do
      assert_difference 'StageCommand.count', 0 do
        project.save!
      end
    end

    it 'does not destroy when already deleted' do
      assert_difference 'StageCommand.count', 0 do
        project.update_attributes!(deleted_at: Time.now)
      end
    end

    it "restores when transaction fails" do
      failed_transaction = Class.new(Project) { before_save { throw :abort } }.find(project.id)
      assert_difference 'StageCommand.count', 0 do
        refute failed_transaction.soft_delete(validate: false)
      end
    end
  end
end
