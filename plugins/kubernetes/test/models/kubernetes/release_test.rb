require_relative "../../test_helper"

describe Kubernetes::Release do
  let(:release) { kubernetes_releases(:live_release) }

  describe 'validations' do
    it 'is valid by default' do
      assert_valid(release)
    end

    it 'test validity of status' do
      Kubernetes::Release::VALID_STATUSES.each do |status|
        assert_valid(release.tap { |kr| kr.status = status })
      end
      refute_valid(release.tap { |kr| kr.status = 'foo' })
      refute_valid(release.tap { |kr| kr.status = nil })
    end
  end
end

