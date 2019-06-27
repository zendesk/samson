# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe LocksHelper do
  include ApplicationHelper

  describe "#delete_lock_options" do
    it "returns the correct options" do
      choices = [
        ['1 hour', 1, 'hours'],
        ['2 hours', 2, 'hours'],
        ['4 hours', 4, 'hours'],
        ['8 hours', 8, 'hours'],
        ['1 day', 1, 'days'],
        ['Never', 0, '']
      ]
      assert_equal choices, delete_lock_options
    end
  end

  describe "#resource_lock_icon" do
    let(:stage) { stages(:test_staging) }

    it "renders nothing when there is no lock" do
      resource_lock_icon(stage).must_be_nil
    end

    it "renders locks" do
      stage.lock = Lock.new(user: users(:deployer))
      resource_lock_icon(stage).must_include "Locked"
    end

    it "renders global locks" do
      Lock.create!(user: users(:deployer))
      resource_lock_icon(stage).must_include "Locked"
    end

    it "strips html from the title so it becomes readable in the hover" do
      Lock.create!(user: users(:deployer), description: "<a href=\"http://hhohoh.com\">wut</a>")
      resource_lock_icon(stage).must_include "Locked: wut by Deployer"
    end

    describe "with a warning" do
      before { stage.lock = Lock.new(warning: true, description: "X", user: users(:deployer)) }

      it "renders warnings" do
        resource_lock_icon(stage).must_include "Warning"
      end

      it "renders lock when there is a warning and a lock" do
        Lock.create!(user: users(:deployer))
        resource_lock_icon(stage).must_include "Locked"
      end
    end
  end

  describe "#global_lock" do
    it "caches nil" do
      Lock.expects(:global).returns []
      global_locks.must_equal []
      global_locks.must_equal []
    end

    it "caches values" do
      Lock.expects(:global).returns [1]
      global_locks.must_equal [1]
      global_locks.must_equal [1]
    end
  end

  describe "#render_lock" do
    let(:stage) { stages(:test_staging) }

    before { view.stubs(current_user: users(:viewer)) }

    it "can render global" do
      Lock.create!(user: users(:admin))
      global_locks # caches
      assert_sql_queries 1 do # loads user to render the lock
        render_locks(:global).must_include "ALL STAGES"
      end
    end

    it "can render specific locks" do
      Lock.create!(user: users(:admin), resource: stage)
      render_locks(stage).must_include "Deployments to stage were locked"
    end

    it "does not render when there is no locks" do
      render_locks(stage).must_be_nil
    end
  end

  describe "#lock_icon" do
    it "renders" do
      lock_icon.must_include "lock"
    end
  end

  describe "#warning_icon" do
    it "renders" do
      warning_icon.must_include "warning"
    end
  end

  describe "#lock_affected" do
    let(:user) { users(:deployer) }
    let(:stage) { stages(:test_staging) }
    let(:lock) { Lock.create!(user: user, resource: stage) }

    it "is everything for global" do
      lock.resource = nil
      lock_affected(lock).must_equal "<a href=\"/projects\">ALL STAGES</a>"
    end

    it "is environment for environment" do
      lock.resource = environments(:production)
      lock_affected(lock).must_equal "<a href=\"/environments/production\">Production</a>"
    end

    it "is project name for Project" do
      lock.resource = projects(:test)
      lock_affected(lock).must_equal "<a href=\"/projects/foo\">Foo</a>"
    end

    it "shows simple text for stage since user can only see it on that page" do
      lock.resource = stage
      lock_affected(lock).must_equal "stage"
    end
  end
end
