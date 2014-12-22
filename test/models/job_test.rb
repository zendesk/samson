require_relative '../test_helper'

describe Job do
  describe 'when project is globally locked' do
    before do
      Lock.create!(user: users(:admin))
    end

    it 'does not allow a job to be created' do
      Job.create.errors[:project].must_equal(['is locked'])
    end
  end
end
