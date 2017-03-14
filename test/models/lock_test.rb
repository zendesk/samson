# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Lock do
  let(:user) { users(:deployer) }
  let(:stage) { stages(:test_staging) }
  let(:environment) { environments(:production) }
  let(:lock) { Lock.create!(user: user, resource: stage) }

  describe "validations" do
    let(:lock) { Lock.new(user: user) }

    it "is valid" do
      assert_valid lock
    end

    it "is invalid with bad type" do
      lock.resource_type = "User"
      refute_valid lock
    end

    describe "warning" do
      before { lock.warning = true }

      it "is invalid without description" do
        refute_valid lock
      end

      it "is valid with description" do
        lock.description = "X"
        assert_valid lock
      end
    end

    describe "#unique_global_lock" do
      before { Lock.create!(user: user) }

      it "is invalid with another global lock" do
        refute_valid lock
      end

      it "is valid when scoped" do
        lock.resource = stage
        assert_valid lock
      end
    end

    describe "#nil_out_blank_resource_type" do
      it "nils blank resource_type" do
        lock.resource_type = ''
        assert_valid lock
        lock.resource_type.must_be_nil
      end
    end
  end

  describe "#affected" do
    it "is everything for global" do
      lock.resource = nil
      lock.affected.must_equal "ALL STAGES"
    end

    it "is environment for environment" do
      lock.resource = environment
      lock.affected.must_equal "Production"
    end

    it "is stage for stage" do
      lock.resource = stage
      lock.affected.must_equal "stage"
    end
  end

  describe ".global" do
    it "does not find local" do
      Lock.global.must_be_empty
    end

    describe "without stage" do
      before { lock.update_attribute(:resource, nil) }

      it "finds global" do
        Lock.global.must_equal [lock]
      end

      it "does not find environment" do
        lock.update_attribute(:resource, environment)
        Lock.global.must_be_empty
      end

      it "does not find deleted" do
        lock.soft_delete!
        Lock.global.must_be_empty
      end
    end
  end

  describe "#summary" do
    it 'says who created the lock' do
      lock.summary.must_include('by Deployer')
    end

    it 'lists the user who created the lock' do
      lock.summary.must_include('by Deployer')
    end

    it 'shows warning' do
      lock.warning = true
      lock.summary.must_include('Warning: ')
    end
  end

  describe "#unlock_summary" do
    it "is emppty when not deleting" do
      lock.expire_summary.must_be_nil
    end

    it "says when unlock is in the future" do
      lock.delete_at = 5.minutes.from_now + 2
      lock.expire_summary.must_equal " and will expire in 5 minutes"
    end

    it "says when unlock failed" do
      lock.delete_at = 5.minutes.ago
      lock.expire_summary.must_equal " and expiration is not working"
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

  describe ".remove_expired_locks" do
    before do
      expired = 2.hour.ago
      Lock.create!(user: users(:deployer), resource: stages(:test_staging), created_at: expired, delete_in: 3600)
      Lock.create!(user: users(:deployer), resource: stages(:test_production), created_at: expired, delete_in: 3600)
      Lock.create!(user: users(:deployer), resource: stages(:test_staging), delete_in: 3600)
      Lock.create!(user: users(:deployer), resource: stages(:test_production), delete_in: 3600)
      Lock.create!(user: users(:deployer), resource: stages(:test_production_pod))

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

  describe ".for_resource" do
    it "finds nothing when nothing is locked" do
      stage # trigger find
      Lock.send :all_cached
      assert_sql_queries 0 do
        Lock.for_resource(stage).must_equal []
      end
    end

    it "finds stage lock" do
      lock # trigger creation
      Lock.send :all_cached
      assert_sql_queries 0 do
        Lock.for_resource(stage).must_equal [lock]
      end
    end

    describe "with environments active" do
      let!(:lock) { Lock.create!(resource: environments(:staging), user: user) }

      before do
        DeployGroup.stubs(enabled?: true)
        stage # load stage
        DeployGroupsStage.first # load column information
      end

      it "finds environment lock on stage" do
        Lock.send :all_cached
        assert_sql_queries 3 do # deploy-groups -> deploy-groups-stages -> environments
          Lock.for_resource(stage).must_equal [lock]
        end
      end

      it "does not check environments on non-environment locks" do
        lock.update_attributes!(resource: stages(:test_production))
        Lock.send :all_cached
        assert_sql_queries 0 do
          Lock.for_resource(stage).must_equal []
        end
      end
    end

    it "finds environment lock" do
      env = environments(:production)
      lock = Lock.create!(resource: env, user: user).reload
      Lock.send :all_cached
      assert_sql_queries 0 do
        Lock.for_resource(env).must_equal [lock]
      end
    end

    it "finds global lock" do
      stage # trigger find
      lock = Lock.create!(user: user)
      Lock.send :all_cached
      assert_sql_queries 0 do
        Lock.for_resource(stage).must_equal [lock]
      end
    end

    describe "with multiple logs" do
      let!(:global) { Lock.create!(user: user) }
      before { lock } # trigger create

      it "combines locks" do
        Lock.for_resource(stage).must_equal [lock, global]
      end

      it "sorts locks for display, so .first will be the highest priority" do
        lock.update_column(:warning, true)
        Lock.for_resource(stage).must_equal [global, lock]
      end
    end
  end

  describe ".locked_for?" do
    it "is false for a lock by myself" do
      lock # create lock
      refute Lock.locked_for?(stage, user)
    end

    it "is true for a lock by another user" do
      lock # create lock
      assert Lock.locked_for?(stage, users(:admin))
    end

    it "is true for a lock when asking for nobody" do
      lock # create lock
      assert Lock.locked_for?(stage, nil)
    end

    it "is false for no lock" do
      refute Lock.locked_for?(stage, users(:admin))
    end

    it "is false for warning" do
      lock.update_column(:warning, true)
      refute Lock.locked_for?(stage, users(:admin))
    end

    it "is true for lock with parallel warnings" do
      DeployGroup.stubs(enabled?: true)
      Lock.create!(user: user, warning: true, description: "DESC")
      Lock.create!(user: user, resource: stage.environments.first)
      Lock.create!(user: user, resource: stage, warning: true, description: "DESC")
      assert Lock.locked_for?(stage, users(:admin))
    end
  end

  describe ".all_cached" do
    it "is cached" do
      assert_sql_queries 1 do
        Lock.send(:all_cached).must_equal []
        Lock.send(:all_cached).must_equal []
      end
    end

    it "expires when lock is created" do
      Lock.send(:all_cached).must_equal []
      lock # trigger create
      Lock.send(:all_cached).must_equal [lock]
    end

    it "expires when lock is updated" do
      lock # trigger create

      Lock.send(:all_cached).must_equal [lock]
      lock.update_attributes(warning: false)
      assert_sql_queries 1 do
        Lock.send(:all_cached).must_equal [lock]
      end
    end

    it "expires when lock is soft deleted" do
      lock # trigger create
      Lock.send(:all_cached).must_equal [lock]
      lock.soft_delete!
      assert_sql_queries 1 do
        Lock.send(:all_cached).must_equal []
      end
    end

    it "does not store associations" do
      lock # trigger create
      Marshal.dump(Lock.send(:all_cached).first).size.must_be :<, 1500
    end
  end

  describe ".cache_key" do
    it "is constant" do
      Lock.cache_key.must_equal Lock.cache_key
    end

    it "updates when locks change" do
      old = Lock.cache_key
      lock
      old.wont_equal Lock.cache_key
    end
  end
end
