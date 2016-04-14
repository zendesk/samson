require_relative '../test_helper'

SingleCov.covered! uncovered: 1

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

      it 'lists the user who created the lock' do
        global_lock.summary.must_include('Locked by Admin')
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

  describe 'individual locks' do
    let(:user_lock) { Lock.create!(user: users(:deployer), stage: stages(:test_staging)) }

    it 'says who created the lock' do
      user_lock.summary.must_include('Locked by Deployer')
    end
  end

  describe '#delete_in=' do
    before { travel_to Time.now }
    after { travel_back }

    it "sets delete_at when given an offset" do
      lock = Lock.new(delete_in: 1.hour)
      lock.delete_at.must_equal(Time.now + 1.hour)
    end

    it "sets delete_at to nil when given nil" do
      lock = Lock.new(delete_in: nil)
      lock.delete_at.must_be_nil
    end

    it "sets delete_at to nil when given an empty string" do
      lock = Lock.new(delete_in: "")
      lock.delete_at.must_be_nil
    end
  end

  describe 'remove_expired_locks' do
    before do
      expired = 2.hour.ago
      Lock.create!(user: users(:deployer), stage: stages(:test_staging), created_at: expired, delete_in: 3600)
      Lock.create!(user: users(:deployer), stage: stages(:test_production), created_at: expired, delete_in: 3600)
      Lock.create!(user: users(:deployer), stage: stages(:test_staging), delete_in: 3600)
      Lock.create!(user: users(:deployer), stage: stages(:test_production), delete_in: 3600)
      Lock.create!(user: users(:deployer), stage: stages(:test_production_pod))

      Lock.remove_expired_locks
    end

    it "removes expired locks" do
      Lock.where("delete_at < ?", Time.now).must_be_empty
    end

    it "leaves unexpired locks alone" do
      Lock.where("delete_at > ?", Time.now).wont_be_empty
    end

    it "leaves indefinite locks alone" do
      Lock.where("delete_at is null").wont_be_empty
    end
  end
end
