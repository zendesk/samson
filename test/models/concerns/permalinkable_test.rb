# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: 1

describe Permalinkable do
  let(:project) { projects(:test) }
  let(:project_url) { "git://foo.com:hello/world.git" }
  let(:other_project) { Project.create!(name: "hello", repository_url: project_url) }

  before { Project.any_instance.stubs(:valid_repository_url).returns(true) }

  describe "#to_param" do
    it "is permalink" do
      project.to_param.must_equal "foo"
    end
  end

  describe "#generate_permalink" do
    it "generates a unique link" do
      project = Project.create!(name: "hello", repository_url: project_url)
      project.permalink.must_equal "world"
    end

    it "generates with id when not unique" do
      Project.create!(name: "hello", repository_url: project_url)
      project = Project.create!(name: "hello", repository_url: project_url)
      project.permalink.must_match /\Aworld-[a-f\d]+\Z/
    end

    it "generates without id when unique in scope" do
      other_project.stages.create!(name: "hello")

      stage = project.stages.create!(name: "hello")
      stage.permalink.must_equal "hello"
    end

    it "removes invalid url characters" do
      stage = project.stages.create!(name: "SDF∂ƒß∂fsƒ.&  XXX")
      stage.permalink.must_equal "sdf-ss-fs-xxx"
    end
  end

  describe ".find_by_param!" do
    it "finds" do
      Project.find_by_param!("foo").must_equal project
    end

    it "behaves like find when not finding" do
      assert_raise ActiveRecord::RecordNotFound do
        Project.find_by_param!("bar")
      end
    end

    it "finds based on scope" do
      stage = stages(:test_staging)
      other_stage = other_project.stages.create!(name: stage.name)
      other_stage.permalink.must_equal stage.permalink
      other_project.stages.find_by_permalink!(stage.permalink).must_equal other_stage
    end
  end

  describe "validations" do
    let(:duplicate) do
      duplicate = record.dup
      duplicate.stubs(:clone_repository).returns(true)
      duplicate.stubs(:clean_repository).returns(true)
      duplicate
    end

    it "does not allow blank because that could never be reached" do
      project.permalink = ''
      refute_valid project
      assert_equal ["Permalink can't be blank"], project.errors.full_messages
    end

    context "unscoped" do
      let(:record) { projects(:test) }

      it "is valid when unique" do
        assert_valid record
      end

      describe "with duplicate" do
        before do
          duplicate.save!
          duplicate.permalink = record.permalink
        end

        it "is invalid when not unique" do
          refute_valid duplicate
          assert_equal ["Permalink has already been taken"], duplicate.errors.full_messages
        end

        it "is invalid when not unique on deleted" do
          record.update_column(:deleted_at, Time.now)
          refute_valid duplicate
          assert_equal ["Permalink has already been taken"], duplicate.errors.full_messages
        end
      end
    end

    context "scoped" do
      let(:record) { stages(:test_staging) }

      it "is valid when unique" do
        assert_valid record
      end

      it "is valid when unique in scope" do
        other_project = projects(:test).dup
        other_project.repository_url.sub!(".git", "x.git")

        other = record.dup
        other.project = other_project
        assert_valid other
      end

      describe "with duplicate" do
        before do
          duplicate.name = 'dup'
          duplicate.save!
          duplicate.permalink = record.permalink
        end

        it "is invalid when not unique in scope" do
          refute_valid duplicate
          assert_equal ["Permalink has already been taken"], duplicate.errors.full_messages
        end

        it "is invalid when not unique in scope on deleted" do
          record.update_column(:deleted_at, Time.now)
          refute_valid duplicate
          # FYI: atm name validation does not include deleted
          assert_equal ["Permalink has already been taken"], duplicate.errors.full_messages
        end
      end
    end
  end
end
