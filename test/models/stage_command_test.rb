# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe StageCommand do
  let(:stage) { stages(:test_staging) }

  describe 'validations' do
    it 'cleans up stage commands when deleting a stage' do
      assert_difference 'StageCommand.count', -2 do
        projects(:test).soft_delete!(validate: false)
      end
    end
  end
end
