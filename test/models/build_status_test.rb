require_relative '../test_helper'

describe BuildStatus do
  let(:build) { builds(:docker_build) }

  def valid_build_status options = {}
    BuildStatus.new(options.reverse_merge(build: build, status: 'pending'))
  end

  describe 'validations' do
    it 'validates presence of build' do
      assert_valid(valid_build_status)
      refute_valid(valid_build_status(build: nil))
    end

    it 'validates the status' do
      BuildStatus::VALID_STATUSES.each do |s|
        assert_valid(valid_build_status(status: s))
      end
      refute_valid(valid_build_status(status: nil))
      refute_valid(valid_build_status(status: 'not a valid status'))
      refute_valid(valid_build_status(status: 123))
    end
  end

  describe 'status helpers' do
    it 'has inquriry methods defined' do
      status = valid_build_status
      BuildStatus::VALID_STATUSES.each do |s|
        assert_respond_to(status, "#{s}?")
      end
    end

    it 'works for each status' do
      assert valid_build_status(status: 'pending').pending?
      refute valid_build_status(status: 'pending').successful?
      refute valid_build_status(status: 'pending').failed?

      refute valid_build_status(status: 'successful').pending?
      assert valid_build_status(status: 'successful').successful?
      refute valid_build_status(status: 'successful').failed?

      refute valid_build_status(status: 'failed').pending?
      refute valid_build_status(status: 'failed').successful?
      assert valid_build_status(status: 'failed').failed?
    end
  end
end
