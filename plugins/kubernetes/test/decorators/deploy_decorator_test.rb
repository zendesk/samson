require_relative '../test_helper'

SingleCov.covered!

describe Deploy do
  describe "#copy_kubernetes_from_stage" do
    let(:stage) { stages(:test_staging) }

    def create_deploy
      Deploy.create!(
        stage: stage,
        reference: "baz",
        job: jobs(:succeeded_test)
      )
    end

    it "copies kubernetes" do
      stage.kubernetes = true
      create_deploy.kubernetes.must_equal true
    end

    it "does not copy no kubernetes" do
      create_deploy.kubernetes.must_equal false
    end
  end
end
