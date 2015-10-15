require_relative "../../test_helper"

describe Kubernetes::Role do
  let(:role) { kubernetes_roles(:app_server) }

  describe 'validations' do
    it 'is valid by default' do
      assert_valid(role)
    end

    it 'test that CPU is valid' do
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.cpu = nil })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.cpu = 'abc' })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.cpu = 0 })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.cpu = -2 })
    end

    it 'test that RAM is valid' do
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.ram = nil })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.ram = 'abc' })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.ram = 0 })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.ram = -2 })
    end

    it 'test validity of deploy strategy' do
      Kubernetes::Role::DEPLOY_STRATEGIES.each do |strategy|
        assert_valid(kubernetes_roles(:app_server).tap { |kr| kr.deploy_strategy = strategy })
      end
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.deploy_strategy = nil })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.deploy_strategy = 'foo' })
    end
  end

  describe '#ram_with_units' do
    it 'works' do
      role.ram = 512
      role.ram_with_units.must_equal '512Mi'
    end
  end
end
