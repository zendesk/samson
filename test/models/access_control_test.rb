# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

# each test is written as a pair of the lowest level that allows access and the one below that forbids access
describe AccessControl do
  def described_scope
    descs = self.class.ancestors.map { |a| a.instance_variable_get(:@desc) }
    descs.fetch(descs.index(AccessControl) - 1).to_sym
  end

  def can?(user, action, project = nil)
    AccessControl.can?(user, action, described_scope, project)
  end

  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:prod_stage) { stages(:test_production) }
  let(:viewer) { users(:viewer) }
  let(:project_deployer) { users(:project_deployer) }
  let(:deployer) { users(:deployer) }
  let(:project_admin) { users(:project_admin) }
  let(:admin) { users(:admin) }
  let(:super_admin) { users(:super_admin) }

  it "fails on unknown resource" do
    assert_raises(ArgumentError) { AccessControl.can?(admin, :write, :sdsdf) }
  end

  describe "access_tokens" do
    it "fails on unknown action" do
      assert_raises(ArgumentError) { can?(admin, :fooo) }
    end

    describe :write do
      it "allows super-admins to update everything" do
        assert can?(super_admin, :write)
      end

      it "allows owners to update their tokens" do
        assert can?(viewer, :write, Doorkeeper::AccessToken.new(resource_owner_id: viewer.id))
      end

      it "forbids viewers to update everything" do
        refute can?(viewer, :write)
      end
    end
  end

  ["builds", "webhooks"].each do |resource|
    describe resource do
      it "fails on unknown action" do
        assert_raises(ArgumentError) { can?(admin, :fooo) }
      end

      describe :read do
        it "allows everyone to read all" do
          assert can?(viewer, :read)
        end
      end

      describe :write do
        it "allows deployers to update everything" do
          assert can?(deployer, :write)
        end

        it "forbids viewers to update anything" do
          refute can?(viewer, :write)
        end
      end
    end
  end

  ["projects", "build_commands", "stages", "user_project_roles"].each do |resource|
    describe resource do
      it "fails on unknown action" do
        assert_raises(ArgumentError) { can?(admin, :fooo) }
      end

      describe :read do
        it "allows everyone to read" do
          assert can?(viewer, :read)
        end
      end

      describe :write do
        it "allows admins to write" do
          assert can?(admin, :write)
        end

        it "allows project admins to write" do
          assert can?(project_admin, :write, project)
        end

        it "forbids deployers write" do
          refute can?(deployer, :write)
        end
      end
    end
  end

  ["vault_servers", "user_merges", "environments"].each do |resource|
    describe resource do
      it "fails on unknown action" do
        assert_raises(ArgumentError) { can?(admin, :fooo) }
      end

      describe :read do
        it "allows anyone to read anyone" do
          assert can?(viewer, :read)
        end
      end

      describe :write do
        it "allows super-admins to update" do
          assert can?(super_admin, :write)
        end

        it "forbids admins to update" do
          refute can?(admin, :write)
        end
      end
    end
  end

  describe "locks" do
    it "fails on unknown action" do
      assert_raises(ArgumentError) { can?(admin, :fooo) }
    end

    describe :read do
      it "allows anyone to read all" do
        assert can?(viewer, :read)
      end
    end

    describe :write do
      describe "project" do
        it "allows admins to update" do
          assert can?(project_admin, :write, project)
        end

        it "forbids deployers to update" do
          refute can?(deployer, :write, project)
        end
      end

      describe "stage" do
        it "allows deployers to update" do
          assert can?(project_deployer, :write, stage)
        end

        it "forbids viewers to update" do
          refute can?(viewer, :write, stage)
        end

        it "allows admins to update with PRODUCTION_STAGE_LOCK_REQUIRES_ADMIN" do
          with_env 'PRODUCTION_STAGE_LOCK_REQUIRES_ADMIN' => 'true' do
            assert can?(admin, :write, stage)
          end
        end

        it "forbids deployers to update with PRODUCTION_STAGE_LOCK_REQUIRES_ADMIN and prod stage" do
          with_env 'PRODUCTION_STAGE_LOCK_REQUIRES_ADMIN' => 'true' do
            refute can?(deployer, :write, prod_stage)
          end
        end
      end

      describe "other" do
        it "allows admins to update" do
          assert can?(admin, :write, Environment.new)
        end

        it "forbids deployers to update" do
          refute can?(deployer, :write, Environment.new)
        end
      end

      describe "global" do
        it "allows admins to update" do
          assert can?(admin, :write)
        end

        it "allows admins to update with PRODUCTION_STAGE_LOCK_REQUIRES_ADMIN" do
          with_env 'PRODUCTION_STAGE_LOCK_REQUIRES_ADMIN' => 'true' do
            assert can?(admin, :write)
          end
        end

        it "forbids deployers to update" do
          refute can?(deployer, :write)
        end
      end
    end
  end

  describe "secrets" do
    it "fails on unknown action" do
      assert_raises(ArgumentError) { can?(admin, :fooo) }
    end

    describe :read do
      it "does not allow viewers to read" do
        refute can?(viewer, :read)
      end

      it "allows deployer to read" do
        assert can?(deployer, :read)
      end

      it "allows any deployer to read" do
        assert can?(project_deployer, :read) # without passing project
      end
    end

    describe :write do
      it "allows admins to update" do
        assert can?(project_admin, :write, project)
      end

      it "forbids deployers to update" do
        refute can?(deployer, :write, project)
      end
    end
  end

  # applies to users controller, users can self-update via profiles controller
  describe "users" do
    it "fails on unknown action" do
      assert_raises(ArgumentError) { can?(admin, :fooo) }
    end

    describe :read do
      it "allows admins to read anyone" do
        assert can?(admin, :read)
      end

      it "forbids deployers to read" do
        refute can?(deployer, :read)
      end
    end

    describe :write do
      it "allows super-admins to update anyone" do
        assert can?(super_admin, :write)
      end

      it "forbids admins to update users roles" do
        refute can?(admin, :write)
      end
    end
  end

  describe "plugins" do
    it "can resolve plugin access" do
      assert AccessControl.can?(admin, :write, :environment_variable_groups)
    end
  end
end
