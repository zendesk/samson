require_relative '../test_helper'

describe Lock do
  describe 'global locks' do
    let(:global_lock) { Lock.create!(user: user) }

    describe 'with a user' do
      let(:user) { users(:admin) }
      before { global_lock }

      it 'is unique' do
        Lock.create(user: user).persisted?.must_equal(false)
      end

      it 'is global' do
        global_lock.global?.must_equal(true)
      end

      it 'is globalled' do
        Lock.global.first.must_equal(global_lock)
      end

      describe 'soft deleted' do
        before { global_lock.soft_delete! }

        it 'is not globalled' do
          Lock.global.must_be_empty
        end
      end
    end

    describe 'without a user' do
      let(:user) { nil }

      it 'is invalid' do
        lambda { global_lock }.must_raise(ActiveRecord::RecordInvalid)
      end
    end
  end
end
