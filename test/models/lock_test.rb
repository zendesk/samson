# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Lock do
  let(:lock) { Lock.create!(user: users(:deployer), stage: stages(:test_staging)) }

  describe "#summary" do
    it 'says who created the lock' do
      lock.summary.must_include('by Deployer')
    end

    describe 'global locks' do
      let(:lock) { Lock.create!(user: user) }

      describe 'with a user' do
        let(:user) { users(:admin) }
        before { lock }

        it 'is unique' do
          refute_valid Lock.new(user: user)
        end

        it 'is global' do
          lock.global?.must_equal(true)
        end

        it 'is globalled' do
          Lock.global.first.must_equal(lock)
        end

        it 'lists the user who created the lock' do
          lock.summary.must_include('by Admin')
        end

        describe 'soft deleted' do
          before { lock.soft_delete! }

          it 'is not globalled' do
            Lock.global.must_be_empty
          end
        end
      end

      describe 'without a user' do
        let(:user) { nil }

        it 'is invalid' do
          lambda { lock }.must_raise(ActiveRecord::RecordInvalid)
        end
      end
    end
  end

  describe "#unlock_summary" do
    it "is emppty when not deleting" do
      lock.unlock_summary.must_equal nil
    end

    it "says when unlock is in the future" do
      lock.delete_at = 5.minutes.from_now + 2
      lock.unlock_summary.must_equal " and will unlock in 5 minutes"
    end

    it "says when unlock failed" do
      lock.delete_at = 5.minutes.ago
      lock.unlock_summary.must_equal " and automatic unlock is not working"
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

  describe '.remove_expired_locks' do
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
