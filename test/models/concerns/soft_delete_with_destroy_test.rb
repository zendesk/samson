# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe SoftDeleteWithDestroy do
  describe 'destroy' do
    it 'destroys dependent: :destroy relations before soft_delete' do
      project = projects(:test)

      assert_difference 'StageCommand.count', -2 do
        project.soft_delete!(validate: false)
      end
    end
  end
end
